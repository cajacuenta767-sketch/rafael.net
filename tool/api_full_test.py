#!/usr/bin/env python3
"""Prueba total de la API refaNet contra un servidor real.

Recorre el ciclo completo que usa la app, en este orden:

  1. Catálogos públicos (estados, ciudades, marcas, modelos, yonkes).
  2. Sesión de cliente por OTP (o token ya emitido con --client-token).
  3. Panel del cliente, creación de solicitud, ciudades, imágenes y envío
     a los yonkes con cobertura.
  4. Alta opcional de un yonke de prueba (--create-yonke) y login de yonke
     (o token ya emitido con --yonke-token).
  5. Perfil, cobertura y bandeja del yonke; marcar como vista; cotizar;
     leer y actualizar la cotización.
  6. Mensajes de la cotización, orden, checkout de Stripe, resultado de
     pago, cancelación de orden y calificación.
  7. Limpieza: elimina las imágenes y cancela la solicitud creada.

Cada paso imprime método, ruta, estatus HTTP y un diagnóstico. Nunca imprime
tokens ni contraseñas. Al final escribe un informe JSON y termina con código 1
si algún paso obligatorio falló.

Uso mínimo (sólo catálogos públicos):

    python tool/api_full_test.py

Ciclo completo. El código OTP se pide por consola cuando llega al teléfono:

    python tool/api_full_test.py --phone=+5215512345678 \
        --yonke-email=yonke@ejemplo.com --yonke-password=Secreta123

Con un yonke nuevo creado durante la prueba:

    python tool/api_full_test.py --phone=+5215512345678 --create-yonke

Sólo depende de la biblioteca estándar de Python 3.8 o superior.
"""

from __future__ import annotations

import argparse
import base64
import getpass
import io
import json
import os
import re
import secrets
import ssl
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zlib
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Tuple

DEFAULT_BASE_URL = (
    "https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net"
)

TOKEN_KEYS = (
    "accesstoken",
    "token",
    "jwt",
    "jwttoken",
    "bearertoken",
    "authtoken",
    "tokenacceso",
    "tokendeacceso",
)
CONTAINER_KEYS = (
    "data",
    "result",
    "resultado",
    "session",
    "sesion",
    "auth",
    "payload",
    "usuario",
    "user",
    "cliente",
    "yonke",
)
YONKE_ID_KEYS = ("yonkeguidid", "yunkeguidid", "yonkeid", "yunkeid", "guidid")
JWT_SHAPE = re.compile(r"^[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*$")


# --------------------------------------------------------------------------
# Utilidades de JSON
# --------------------------------------------------------------------------


def _lower_map(obj: Any) -> Dict[str, Any]:
    if not isinstance(obj, dict):
        return {}
    return {str(k).lower(): v for k, v in obj.items()}


def unwrap(obj: Any) -> Any:
    """Devuelve el contenido útil de un envoltorio ApiResponseGlobal."""
    if isinstance(obj, dict):
        low = _lower_map(obj)
        for key in ("data", "result", "resultado", "items", "registros"):
            if key in low and low[key] is not None:
                return low[key]
    return obj


def as_list(obj: Any) -> List[Any]:
    obj = unwrap(obj)
    if isinstance(obj, list):
        return obj
    if isinstance(obj, dict):
        low = _lower_map(obj)
        for key in ("items", "registros", "data", "result", "lista", "elementos"):
            if isinstance(low.get(key), list):
                return low[key]
    return []


def find_key(obj: Any, names: Iterable[str], depth: int = 4) -> Any:
    """Busca la primera clave (sin distinguir mayúsculas) en un JSON anidado."""
    wanted = tuple(n.lower() for n in names)
    if depth < 0:
        return None
    if isinstance(obj, dict):
        low = _lower_map(obj)
        for name in wanted:
            if name in low and low[name] not in (None, ""):
                return low[name]
        for value in obj.values():
            if isinstance(value, (dict, list)):
                found = find_key(value, wanted, depth - 1)
                if found not in (None, ""):
                    return found
    elif isinstance(obj, list):
        for item in obj[:20]:
            found = find_key(item, wanted, depth - 1)
            if found not in (None, ""):
                return found
    return None


def extract_token(obj: Any) -> Optional[str]:
    if isinstance(obj, str) and JWT_SHAPE.match(obj.strip()):
        return obj.strip()
    if not isinstance(obj, dict):
        return None
    low = _lower_map(obj)
    for key in TOKEN_KEYS:
        value = low.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    for key in CONTAINER_KEYS:
        inner = low.get(key)
        token = extract_token(inner)
        if token:
            return token
    return None


def jwt_claims(token: str) -> Dict[str, Any]:
    try:
        payload = token.split(".")[1]
        payload += "=" * (-len(payload) % 4)
        return json.loads(base64.urlsafe_b64decode(payload.encode()))
    except Exception:  # noqa: BLE001 - un token opaco no es un error aquí
        return {}


def describe_shape(obj: Any, limit: int = 12) -> str:
    """Resume la forma de una respuesta sin exponer valores."""
    obj = unwrap(obj)
    if isinstance(obj, list):
        if not obj:
            return "lista vacía"
        return f"lista[{len(obj)}] de " + describe_shape(obj[0], limit)
    if isinstance(obj, dict):
        keys = list(obj.keys())
        extra = "" if len(keys) <= limit else f" (+{len(keys) - limit})"
        return "{" + ", ".join(keys[:limit]) + extra + "}"
    if obj is None:
        return "null"
    return type(obj).__name__


# --------------------------------------------------------------------------
# Cliente HTTP
# --------------------------------------------------------------------------


@dataclass
class Response:
    status: int
    body: Any
    raw: bytes
    content_type: str
    elapsed_ms: int
    error: Optional[str] = None

    @property
    def ok(self) -> bool:
        return 200 <= self.status < 300

    @property
    def envelope_success(self) -> Optional[bool]:
        if isinstance(self.body, dict):
            low = _lower_map(self.body)
            if "success" in low:
                return bool(low["success"])
        return None


class Api:
    def __init__(self, base_url: str, timeout: float, insecure: bool) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.token: Optional[str] = None
        context = ssl.create_default_context()
        if insecure:
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPSHandler(context=context),
            _NoRedirect(),
        )

    def request(
        self,
        method: str,
        path: str,
        *,
        query: Optional[Dict[str, Any]] = None,
        json_body: Any = None,
        multipart: Optional[List[Tuple[str, Any]]] = None,
        token: Optional[str] = None,
    ) -> Response:
        url = self.base_url + path
        if query:
            clean = {k: v for k, v in query.items() if v is not None}
            if clean:
                url += "?" + urllib.parse.urlencode(clean)
        headers = {"Accept": "application/json"}
        data: Optional[bytes] = None
        if multipart is not None:
            data, content_type = encode_multipart(multipart)
            headers["Content-Type"] = content_type
        elif json_body is not None:
            data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        bearer = token if token is not None else self.token
        if bearer:
            headers["Authorization"] = f"Bearer {bearer}"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        started = time.monotonic()
        try:
            with self.opener.open(req, timeout=self.timeout) as resp:
                raw = resp.read()
                status = resp.status
                ctype = resp.headers.get("Content-Type", "")
        except urllib.error.HTTPError as err:
            raw = err.read()
            status = err.code
            ctype = err.headers.get("Content-Type", "") if err.headers else ""
        except urllib.error.URLError as err:
            elapsed = int((time.monotonic() - started) * 1000)
            return Response(0, None, b"", "", elapsed, error=str(err.reason))
        except Exception as err:  # noqa: BLE001
            elapsed = int((time.monotonic() - started) * 1000)
            return Response(0, None, b"", "", elapsed, error=repr(err))
        elapsed = int((time.monotonic() - started) * 1000)
        body: Any = None
        if raw:
            try:
                body = json.loads(raw.decode("utf-8"))
            except Exception:  # noqa: BLE001
                body = raw.decode("utf-8", "replace")
        return Response(status, body, raw, ctype, elapsed)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Las redirecciones (Stripe, /pago/exitoso) se reportan, no se siguen."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: D401
        return None


def encode_multipart(fields: List[Tuple[str, Any]]) -> Tuple[bytes, str]:
    boundary = "----refanet" + secrets.token_hex(12)
    out = io.BytesIO()
    for name, value in fields:
        out.write(f"--{boundary}\r\n".encode())
        if isinstance(value, tuple):
            filename, content, mime = value
            out.write(
                f'Content-Disposition: form-data; name="{name}"; '
                f'filename="{filename}"\r\n'.encode()
            )
            out.write(f"Content-Type: {mime}\r\n\r\n".encode())
            out.write(content)
        else:
            out.write(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
            out.write(str(value).encode("utf-8"))
        out.write(b"\r\n")
    out.write(f"--{boundary}--\r\n".encode())
    return out.getvalue(), f"multipart/form-data; boundary={boundary}"


def tiny_png(width: int = 8, height: int = 8) -> bytes:
    """PNG válido de 8x8 gris, para probar subidas sin archivos externos."""

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    row = b"\x00" + b"\x80\x80\x80" * width
    raw = row * height
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


# --------------------------------------------------------------------------
# Registro de resultados
# --------------------------------------------------------------------------


@dataclass
class Step:
    name: str
    method: str
    path: str
    status: int
    outcome: str  # OK | FALLA | AVISO | OMITIDO
    note: str
    elapsed_ms: int = 0
    shape: str = ""


@dataclass
class Report:
    steps: List[Step] = field(default_factory=list)

    def add(self, step: Step) -> Step:
        self.steps.append(step)
        icon = {"OK": "✔", "FALLA": "✖", "AVISO": "△", "OMITIDO": "·"}[step.outcome]
        status = f"{step.status}" if step.status else "---"
        line = f"{icon} {step.outcome:<7} {step.method:<6} {status:>3} {step.path}"
        print(line)
        if step.note:
            print(f"    {step.note}")
        if step.shape and step.outcome != "OMITIDO":
            print(f"    forma: {step.shape}")
        return step

    def skip(self, name: str, method: str, path: str, why: str) -> None:
        self.add(Step(name, method, path, 0, "OMITIDO", why))

    @property
    def failures(self) -> List[Step]:
        return [s for s in self.steps if s.outcome == "FALLA"]

    @property
    def warnings(self) -> List[Step]:
        return [s for s in self.steps if s.outcome == "AVISO"]


class Runner:
    def __init__(self, api: Api, report: Report) -> None:
        self.api = api
        self.report = report

    def call(
        self,
        name: str,
        method: str,
        path: str,
        *,
        query: Optional[Dict[str, Any]] = None,
        json_body: Any = None,
        multipart: Optional[List[Tuple[str, Any]]] = None,
        token: Optional[str] = None,
        expect: Optional[Iterable[str]] = None,
        optional: bool = False,
        accept_status: Iterable[int] = (),
    ) -> Response:
        resp = self.api.request(
            method,
            path,
            query=query,
            json_body=json_body,
            multipart=multipart,
            token=token,
        )
        shown = re.sub(r"[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}", "{guid}", path)
        if resp.error:
            self.report.add(
                Step(name, method, shown, 0, "FALLA", f"sin respuesta: {resp.error}")
            )
            return resp
        outcome = "OK"
        notes: List[str] = []
        accepted = set(accept_status)
        if not resp.ok and resp.status not in accepted:
            outcome = "AVISO" if optional else "FALLA"
            notes.append(_error_summary(resp))
        elif resp.envelope_success is False:
            outcome = "AVISO" if optional else "FALLA"
            notes.append("HTTP 200 pero success=false: " + _error_summary(resp))
        elif expect:
            rows = as_list(resp.body)
            payload = unwrap(unwrap(resp.body))
            sample = rows[0] if rows else payload
            if isinstance(payload, list) and not payload:
                notes.append("lista vacía; no se pudo validar la forma")
            else:
                missing = [k for k in expect if find_key(sample, [k], depth=1) is None]
                if missing:
                    outcome = "AVISO"
                    notes.append("faltan claves que la app lee: " + ", ".join(missing))
        if resp.ok and not resp.raw:
            notes.append("cuerpo vacío")
        if resp.ok and "json" not in resp.content_type and resp.raw:
            notes.append(f"Content-Type inesperado: {resp.content_type or 'ninguno'}")
        self.report.add(
            Step(
                name,
                method,
                shown,
                resp.status,
                outcome,
                "; ".join(notes),
                resp.elapsed_ms,
                describe_shape(resp.body),
            )
        )
        return resp


def _error_summary(resp: Response) -> str:
    body = resp.body
    if isinstance(body, dict):
        low = _lower_map(body)
        for key in ("message", "mensaje", "title", "error", "detail"):
            if isinstance(low.get(key), str):
                text = low[key]
                errors = low.get("errors")
                if errors:
                    text += " | errors=" + json.dumps(errors, ensure_ascii=False)[:300]
                return text[:400]
        return json.dumps(body, ensure_ascii=False)[:400]
    if isinstance(body, str) and body.strip():
        stripped = re.sub(r"<[^>]+>", " ", body)
        return re.sub(r"\s+", " ", stripped).strip()[:300]
    return f"HTTP {resp.status} sin cuerpo"


# --------------------------------------------------------------------------
# Escenarios
# --------------------------------------------------------------------------


@dataclass
class Context:
    state_id: Optional[int] = None
    city_id: Optional[int] = None
    city_ids: List[int] = field(default_factory=list)
    brand_id: Optional[int] = None
    model_id: Optional[int] = None
    client_token: Optional[str] = None
    client_user_id: Optional[str] = None
    yonke_token: Optional[str] = None
    yonke_id: Optional[str] = None
    request_id: Optional[str] = None
    image_ids: List[str] = field(default_factory=list)
    request_yonke_id: Optional[str] = None
    quote_id: Optional[str] = None
    order_id: Optional[str] = None
    checkout_session_id: Optional[str] = None
    created_yonke_email: Optional[str] = None


def _first_int(items: List[Any]) -> Optional[int]:
    for item in items:
        value = find_key(item, ["id"], depth=0)
        if isinstance(value, int):
            return value
        if isinstance(value, str) and value.isdigit():
            return int(value)
    return None


def _guid_of(obj: Any, names: Iterable[str] = ("guidId", "guid", "id")) -> Optional[str]:
    value = find_key(obj, names, depth=2)
    if isinstance(value, str):
        try:
            return str(uuid.UUID(value))
        except ValueError:
            return None
    return None


def run_catalogs(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 1. Catálogos públicos ==")
    states = r.call("Estados", "GET", "/api/Utilerias/entidades", expect=["id", "entidad"])
    ctx.state_id = args.state_id or _first_int(as_list(states.body))
    if ctx.state_id is None:
        r.report.skip("Ciudades", "GET", "/api/Utilerias/entidad/{id}/ciudades", "sin estados")
    else:
        r.call("Estado por id", "GET", f"/api/Utilerias/entidad/{ctx.state_id}", optional=True)
        cities = r.call(
            "Ciudades del estado",
            "GET",
            f"/api/Utilerias/entidad/{ctx.state_id}/ciudades",
            expect=["id", "ciudad"],
        )
        found = [
            v
            for v in (find_key(c, ["id"], depth=0) for c in as_list(cities.body))
            if isinstance(v, int)
        ]
        ctx.city_ids = found[:3]
        ctx.city_id = args.city_id or (found[0] if found else None)
        if ctx.city_id is not None:
            r.call("Ciudad por id", "GET", f"/api/Utilerias/ciudad/{ctx.city_id}", optional=True)

    brands = r.call("Marcas", "GET", "/api/Utilerias/marcas", expect=["id", "marca"])
    ctx.brand_id = args.brand_id or _first_int(as_list(brands.body))
    if ctx.brand_id is None:
        r.report.skip("Modelos", "GET", "/api/Utilerias/modelos", "sin marcas")
    else:
        r.call("Marca por id", "GET", f"/api/Utilerias/marca/{ctx.brand_id}", optional=True)
        models = r.call(
            "Modelos de la marca",
            "GET",
            "/api/Utilerias/modelos",
            query={"marcaId": ctx.brand_id},
            expect=["id", "modelo"],
        )
        ctx.model_id = args.model_id or _first_int(as_list(models.body))
        if ctx.model_id is not None:
            r.call("Modelo por id", "GET", f"/api/Utilerias/modelo/{ctx.model_id}", optional=True)

    r.call(
        "Yonkes paginados (sin sesión)",
        "GET",
        "/api/Yonkes/byPage",
        query={"Page": 1, "CantidadRegistrosPorPagina": 5, "ciudadId": ctx.city_id},
        optional=True,
        expect=["guidId", "nombre"],
    )


def run_client_login(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 2. Sesión de cliente ==")
    if args.client_token:
        ctx.client_token = args.client_token
        print("· usando --client-token")
    elif args.phone:
        otp = r.call(
            "Solicitar OTP",
            "POST",
            "/api/ClienteAuth/solicitar-otp",
            json_body={"telefono": args.phone},
            token="",
        )
        if not otp.ok:
            return
        code = args.otp or _prompt_code()
        if not code:
            r.report.skip("Verificar OTP", "POST", "/api/ClienteAuth/verificar-otp", "sin código")
            return
        verify = r.call(
            "Verificar OTP",
            "POST",
            "/api/ClienteAuth/verificar-otp",
            json_body={"telefono": args.phone, "codigo": code},
            token="",
        )
        ctx.client_token = extract_token(verify.body)
        if verify.ok and not ctx.client_token:
            r.report.add(
                Step(
                    "Token de cliente",
                    "POST",
                    "/api/ClienteAuth/verificar-otp",
                    verify.status,
                    "FALLA",
                    "la respuesta no trae ningún token reconocible "
                    f"(claves: {describe_shape(verify.body)})",
                )
            )
    else:
        r.report.skip(
            "Sesión de cliente", "POST", "/api/ClienteAuth/verificar-otp",
            "pasa --phone=<+52...> o --client-token=<jwt>",
        )
        return

    if ctx.client_token:
        claims = jwt_claims(ctx.client_token)
        ctx.client_user_id = str(
            claims.get("sub") or claims.get("nameid") or claims.get("userId") or ""
        ) or None
        exp = claims.get("exp")
        note = "token JWT" if claims else "token opaco (no es JWT decodificable)"
        if claims and not ctx.client_user_id:
            note += "; sin sub/nameid: la app no podrá identificar al remitente en mensajes"
        if isinstance(exp, (int, float)) and exp < time.time():
            note += "; el token ya está expirado"
        r.report.add(Step("Token de cliente", "-", "(claims)", 200, "OK" if ctx.client_user_id else "AVISO", note))
        r.call(
            "Registrar dispositivo cliente",
            "POST",
            "/api/ClienteAuth/registrar-dispositivo",
            json_body={
                "firebaseToken": "prueba-" + secrets.token_hex(8),
                "plataforma": "android",
                "modelo": "api_full_test",
            },
            token=ctx.client_token,
            optional=True,
        )


def _prompt_code() -> Optional[str]:
    if not sys.stdin.isatty():
        print("    (sin consola interactiva: pasa --otp=<código>)")
        return None
    try:
        return input("    Escribe el código OTP recibido (6 dígitos): ").strip() or None
    except EOFError:
        return None


def run_client_flow(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 3. Flujo del cliente ==")
    if not ctx.client_token:
        r.report.skip("Flujo del cliente", "-", "/api/DashboardSuscriptores/*", "sin sesión de cliente")
        return
    r.api.token = ctx.client_token

    r.call("Resumen del panel", "GET", "/api/DashboardSuscriptores/resumen")
    r.call(
        "Mis solicitudes (cliente)",
        "GET",
        "/api/DashboardSuscriptores/mis-solicitudes",
        query={"Page": 1, "CantidadRegistrosPorPagina": 10},
        expect=["guidId", "estatusSolicitud", "piezaBuscada"],
    )
    r.call("Mis cotizaciones (cliente)", "GET", "/api/DashboardSuscriptores/mis-cotizaciones")
    r.call("Solicitud reciente", "GET", "/api/DashboardSuscriptores/mi-solicitud-reciente", optional=True)
    r.call(
        "Solicitudes paginadas",
        "GET",
        "/api/Solicitudes/AllPaged",
        query={"Page": 1, "CantidadRegistrosPorPagina": 5},
        optional=True,
    )

    if ctx.brand_id is None or ctx.model_id is None or ctx.city_id is None:
        r.report.skip("Crear solicitud", "POST", "/api/Solicitudes", "faltan marca, modelo o ciudad de catálogo")
        return

    created = r.call(
        "Crear solicitud",
        "POST",
        "/api/Solicitudes",
        json_body={
            "marcaId": ctx.brand_id,
            "modeloId": ctx.model_id,
            "año": 2018,
            "motor": "2.0L",
            "transmicion": "Automática",
            "piezaBuscada": "Prueba automática api_full_test",
            "numeroParte": "TEST-" + secrets.token_hex(3).upper(),
            "descripcion": "Solicitud creada por tool/api_full_test.py; se cancela al final.",
            "ciudadesIds": ctx.city_ids or [ctx.city_id],
        },
    )
    ctx.request_id = _guid_of(created.body, ["guidId", "solicitudGuidId", "guid"])
    if created.ok and not ctx.request_id:
        recent = r.call("Recuperar guid desde solicitud reciente", "GET", "/api/DashboardSuscriptores/mi-solicitud-reciente")
        ctx.request_id = _guid_of(recent.body, ["guidId"])
        if not ctx.request_id:
            r.report.add(Step("Guid de la solicitud", "POST", "/api/Solicitudes", created.status, "FALLA",
                              "la respuesta de creación no devuelve guidId y tampoco se pudo recuperar"))
    if not ctx.request_id:
        return

    rid = ctx.request_id
    r.call("Detalle de solicitud", "GET", f"/api/Solicitudes/{rid}",
           expect=["guidId", "marca", "modelo", "estatusSolicitud", "totalCotizaciones"])
    r.call("Ciudades de la solicitud", "GET", f"/api/SolicitudCiudades/{rid}/ciudades")
    r.call("¿Existe ciudad en solicitud?", "GET", "/api/SolicitudCiudades/existe",
           query={"solicitudGuidId": rid, "ciudadId": ctx.city_id})
    extra_city = next((c for c in ctx.city_ids if c != ctx.city_id), None)
    if extra_city is not None:
        r.call("Agregar una ciudad", "POST", f"/api/SolicitudCiudades/{rid}/ciudad/{extra_city}", optional=True)
        r.call("Quitar una ciudad", "DELETE", f"/api/SolicitudCiudades/{rid}/ciudad/{extra_city}", optional=True)
    r.call("Reemplazar ciudades", "PUT", f"/api/SolicitudCiudades/{rid}/ciudades",
           json_body=ctx.city_ids or [ctx.city_id], optional=True)
    r.call("Agregar varias ciudades", "POST", f"/api/SolicitudCiudades/{rid}/ciudades",
           json_body=[ctx.city_id], optional=True)

    png = tiny_png()
    upload = r.call(
        "Subir imágenes",
        "POST",
        f"/api/SolicitudesImagenes/{rid}",
        multipart=[
            ("imagenes", ("prueba1.png", png, "image/png")),
            ("imagenes", ("prueba2.png", png, "image/png")),
        ],
    )
    listing = r.call("Imágenes de la solicitud", "GET", f"/api/SolicitudesImagenes/solicitud/{rid}",
                     expect=["guidId", "urlImagen"])
    for item in as_list(listing.body):
        guid = _guid_of(item, ["guidId"])
        if guid:
            ctx.image_ids.append(guid)
    if upload.ok and not ctx.image_ids:
        r.report.add(Step("Imágenes subidas", "GET", f"/api/SolicitudesImagenes/solicitud/{{guid}}",
                          listing.status, "AVISO", "la subida respondió OK pero el listado no devuelve imágenes"))
    if ctx.image_ids:
        r.call("Imagen por guid", "GET", f"/api/SolicitudesImagenes/{ctx.image_ids[0]}", optional=True)

    r.call("Enviar solicitud a yonkes", "POST", f"/api/SolicitudYonkes/{rid}/enviar")


def run_yonke_login(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 4. Sesión de yonke ==")
    r.api.token = None
    email, password = args.yonke_email, args.yonke_password

    if args.create_yonke:
        if ctx.city_id is None:
            r.report.skip("Crear yonke", "POST", "/api/Yonkes", "sin ciudad de catálogo")
        else:
            stamp = secrets.token_hex(4)
            email = f"prueba.{stamp}@refanet-test.local"
            password = "Prueba-" + secrets.token_hex(6)
            created = r.call(
                "Crear yonke de prueba",
                "POST",
                "/api/Yonkes",
                multipart=[
                    ("Nombre", f"Yonke prueba {stamp}"),
                    ("Responsable", "api_full_test"),
                    ("Telefono", "5550000000"),
                    ("Correo", email),
                    ("Direccion", "Calle de prueba 1"),
                    ("CP", "01000"),
                    ("CiudadId", str(ctx.city_id)),
                    ("Password", password),
                    ("ConfirmPassword", password),
                    ("LogoUrl", ("logo.png", tiny_png(), "image/png")),
                ],
                token="",
            )
            if created.ok:
                ctx.created_yonke_email = email
                print(f"    yonke creado con correo {email} (la contraseña no se imprime)")
                guid = _guid_of(created.body, ["guidId"])
                if guid:
                    ctx.yonke_id = guid
                    r.report.add(Step("Yonke recién creado", "GET", "/api/Yonkes/{guid}", 0, "AVISO",
                                      "recuerda que `autorizado` puede requerir aprobación manual antes de recibir solicitudes"))
            else:
                email, password = args.yonke_email, args.yonke_password

    if args.yonke_token:
        ctx.yonke_token = args.yonke_token
        print("· usando --yonke-token")
    elif email and password:
        login = r.call(
            "Login de yonke",
            "POST",
            "/api/YonkeAuth/login",
            json_body={"correo": email, "password": password},
            token="",
        )
        ctx.yonke_token = extract_token(login.body)
        if login.ok and not ctx.yonke_token:
            r.report.add(Step("Token de yonke", "POST", "/api/YonkeAuth/login", login.status, "FALLA",
                              f"la respuesta no trae token reconocible (claves: {describe_shape(login.body)})"))
        guid = find_key(login.body, YONKE_ID_KEYS, depth=3)
        if isinstance(guid, str):
            ctx.yonke_id = guid
    else:
        r.report.skip("Sesión de yonke", "POST", "/api/YonkeAuth/login",
                      "pasa --yonke-email y --yonke-password, --yonke-token o --create-yonke")
        return

    if ctx.yonke_token:
        claims = jwt_claims(ctx.yonke_token)
        if not ctx.yonke_id:
            for key in ("yonkeGuidId", "yonkeId", "guidId"):
                if isinstance(claims.get(key), str):
                    ctx.yonke_id = claims[key]
                    break
        ctx.yonke_id = args.yonke_id or ctx.yonke_id
        outcome = "OK" if ctx.yonke_id else "FALLA"
        note = ("yonkeGuidId disponible" if ctx.yonke_id else
                "ni la respuesta del login ni el JWT traen yonkeGuidId: perfil, cobertura y "
                "dispositivos del yonke no funcionarán en la app")
        r.report.add(Step("Identidad del yonke", "-", "(login/claims)", 200, outcome, note))


def run_yonke_flow(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 5. Flujo del yonke ==")
    if not ctx.yonke_token:
        r.report.skip("Flujo del yonke", "-", "/api/Yonkes/*", "sin sesión de yonke")
        return
    r.api.token = ctx.yonke_token

    if ctx.yonke_id:
        yid = ctx.yonke_id
        r.call("Perfil del yonke", "GET", f"/api/Yonkes/{yid}", expect=["guidId", "nombre", "correo", "ciudadId"])
        r.call("Cobertura del yonke", "GET", f"/api/YonkesCoberturas/guid/{yid}")
        if ctx.city_ids or ctx.city_id:
            r.call("Actualizar cobertura", "PUT", "/api/YonkesCoberturas",
                   json_body={"yonkeGuidId": yid, "ciudadesIds": ctx.city_ids or [ctx.city_id]})
        r.call("Actualizar información del yonke", "PUT", f"/api/Yonkes/updateInfo/byGuidId/{yid}",
               json_body={"nombre": None, "responsable": "api_full_test", "telefono": None,
                          "direccion": None, "cp": 0, "ciudadId": ctx.city_id or 0,
                          "latitud": None, "longitud": None},
               optional=True)
        r.call("Actualizar logo", "PUT", "/api/Yonkes/ActualizarLogo",
               multipart=[("GuidId", yid), ("LogoUrl", ("logo.png", tiny_png(), "image/png"))],
               optional=True)
        r.call("Registrar dispositivo yonke", "POST", "/api/YonkesDispositivos",
               json_body={"yonkeGuidId": yid, "firebaseToken": "prueba-" + secrets.token_hex(8),
                          "plataforma": "android", "modelo": "api_full_test"},
               optional=True)
        r.call("Calificaciones del yonke", "GET", f"/api/YonkesCalificaciones/{yid}", optional=True)
    else:
        r.report.skip("Perfil/cobertura del yonke", "GET", "/api/Yonkes/{guid}", "sin yonkeGuidId")

    r.call("Resumen del panel (yonke)", "GET", "/api/DashboardSuscriptores/resumen", optional=True)
    inbox = r.call(
        "Mis solicitudes (yonke)",
        "GET",
        "/api/DashboardSuscriptores/mis-solicitudes",
        query={"Page": 1, "CantidadRegistrosPorPagina": 50},
    )
    rows = as_list(inbox.body)
    if inbox.ok:
        if not rows:
            r.report.add(Step("Bandeja del yonke", "GET", "/api/DashboardSuscriptores/mis-solicitudes",
                              inbox.status, "AVISO",
                              "la bandeja está vacía: el yonke no tiene cobertura en la ciudad de la solicitud, "
                              "no está autorizado, o el envío no generó SolicitudYonkes"))
        else:
            sample = rows[0]
            # Forma real confirmada el 13/09/2026: la solicitud plana
            # (Solicitud_Busqueda_DTO) con guidId, folio, marca, piezaBuscada.
            # También se acepta la forma anidada SolicitudYonkes.
            nested = find_key(sample, ["solicitudes"], depth=0) is not None
            if find_key(sample, ["guidId"], depth=0) is None or (
                not nested and find_key(sample, ["piezaBuscada"], depth=0) is None
            ):
                r.report.add(Step("Forma de la bandeja", "GET", "/api/DashboardSuscriptores/mis-solicitudes",
                                  inbox.status, "FALLA",
                                  "cada fila debe traer guidId y piezaBuscada (solicitud plana) o "
                                  "guidId, solicitudGuidId y solicitudes (SolicitudYonkes); "
                                  f"claves: {describe_shape(sample)}"))
            for row in rows:
                sol = find_key(row, ["solicitudGuidId"], depth=1) or find_key(row, ["guidId"], depth=0)
                if ctx.request_id and isinstance(sol, str) and sol.lower() == ctx.request_id.lower():
                    ctx.request_yonke_id = _guid_of(row, ["guidId"])
                    break
            if ctx.request_yonke_id is None:
                ctx.request_yonke_id = args.request_yonke_id or _guid_of(rows[0], ["guidId"])
                if ctx.request_id:
                    r.report.add(Step("Solicitud enviada en bandeja", "GET",
                                      "/api/DashboardSuscriptores/mis-solicitudes", inbox.status, "AVISO",
                                      "la solicitud creada en el paso 3 no aparece en la bandeja del yonke; "
                                      "se usará la primera asignación disponible"))
    r.call("Mis cotizaciones (yonke)", "GET", "/api/DashboardSuscriptores/mis-cotizaciones", optional=True)

    if not ctx.request_yonke_id:
        r.report.skip("Cotizar", "POST", "/api/CotizacionYonke", "sin solicitudYonkeGuidId")
        return

    ryid = ctx.request_yonke_id
    r.call("Marcar solicitud como vista", "PUT", f"/api/SolicitudYonkes/{ryid}/vista")
    quote = r.call(
        "Registrar cotización",
        "POST",
        "/api/CotizacionYonke",
        query={"solicitudYonkeGuidId": ryid},
        multipart=[
            ("Precio", "1500.50"),
            ("Disponible", "true"),
            ("EsNueva", "false"),
            ("MarcaId", str(ctx.brand_id or 0)),
            ("NumeroParte", "TEST-COT"),
            ("Comentarios", "Cotización de prueba api_full_test"),
            ("TiempoEntregaDias", "3"),
            ("DiasGarantia", "30"),
            ("EnvioDisponible", "true"),
            ("CostoEnvio", "120"),
            ("TieneGarantia", "true"),
            ("Imagenes", ("cotizacion.png", tiny_png(), "image/png")),
        ],
    )
    ctx.quote_id = _guid_of(quote.body, ["guidId", "cotizacionGuidId", "guid"])
    if quote.ok and not ctx.quote_id:
        mine = r.call("Recuperar guid de cotización", "GET", "/api/DashboardSuscriptores/mis-cotizaciones")
        for row in as_list(mine.body):
            if find_key(row, ["solicitudYonkeGuidId"], depth=1) == ryid:
                ctx.quote_id = _guid_of(row, ["guidId"])
                break
        if not ctx.quote_id:
            r.report.add(Step("Guid de la cotización", "POST", "/api/CotizacionYonke", quote.status, "FALLA",
                              "la respuesta no devuelve guidId y no se pudo recuperar de mis-cotizaciones"))
    if not ctx.quote_id:
        return
    qid = ctx.quote_id
    r.call("Detalle de cotización", "GET", f"/api/CotizacionYonke/{qid}",
           expect=["guidId", "precio", "disponible", "activo", "solicitudYonkes"])
    r.call("Actualizar cotización", "PUT", f"/api/CotizacionYonke/{qid}",
           json_body={"precio": 1450.0, "disponible": True, "esNueva": False, "marcaId": ctx.brand_id or 0,
                      "numeroParte": "TEST-COT", "comentarios": "Precio ajustado", "tiempoEntregaDias": 2,
                      "diasGarantia": 30, "envioDisponible": True, "costoEnvio": 100.0,
                      "tieneGarantia": True, "imagenes": None})
    r.call("Mensaje del yonke", "POST", "/api/SolicitudCotizacionMensajes",
           json_body={"solicitudCotizacionGuidId": qid, "mensaje": "Hola, soy el yonke de prueba."}, optional=True)


def run_client_purchase(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 6. Compra del cliente ==")
    if not ctx.client_token:
        r.report.skip("Compra", "-", "/api/Orden", "sin sesión de cliente")
        return
    r.api.token = ctx.client_token
    qid = ctx.quote_id or args.quote_id
    if not qid:
        r.report.skip("Compra", "-", "/api/Orden", "sin cotización (pasa --quote-id=<guid>)")
        return

    r.call("Mis cotizaciones tras cotizar", "GET", "/api/DashboardSuscriptores/mis-cotizaciones",
           expect=["guidId", "precio"])
    r.call("Enviar mensaje (cliente)", "POST", "/api/SolicitudCotizacionMensajes",
           json_body={"solicitudCotizacionGuidId": qid, "mensaje": "Hola, ¿sigue disponible?"})
    msgs = r.call("Mensajes de la cotización", "GET", f"/api/SolicitudCotizacionMensajes/{qid}",
                  expect=["mensaje", "tipoRemitenteId", "fechaCreacion"])
    r.call("No leídos", "GET", f"/api/SolicitudCotizacionMensajes/{qid}/no-leidos")
    r.call("Marcar leídos", "PUT", f"/api/SolicitudCotizacionMensajes/{qid}/leer")
    if msgs.ok and ctx.client_user_id:
        senders = {str(find_key(m, ["usuarioId"], depth=0)) for m in as_list(msgs.body)}
        if senders and ctx.client_user_id not in senders:
            r.report.add(Step("Remitente de mensajes", "GET", "/api/SolicitudCotizacionMensajes/{guid}", msgs.status,
                              "AVISO", "ningún mensaje tiene usuarioId igual al sub del token; la app no podrá "
                              "distinguir los mensajes propios salvo por tipoRemitenteId"))

    order = r.call("Crear orden", "POST", "/api/Orden", json_body={"cotizacionGuidId": qid})
    ctx.order_id = _guid_of(order.body, ["guidId", "ordenGuidId", "guid"])
    if order.ok and not ctx.order_id:
        by_quote = r.call("Orden por cotización", "GET", f"/api/Orden/cotizacion/{qid}")
        ctx.order_id = _guid_of(by_quote.body, ["guidId", "ordenGuidId"])
        if not ctx.order_id:
            r.report.add(Step("Guid de la orden", "POST", "/api/Orden", order.status, "FALLA",
                              "la respuesta no devuelve el guid de la orden"))
    else:
        r.call("Orden por cotización", "GET", f"/api/Orden/cotizacion/{qid}", optional=True)
    if not ctx.order_id:
        return
    oid = ctx.order_id
    r.call("Detalle de orden", "GET", f"/api/Orden/{oid}", expect=["guidId"])

    checkout = r.call("Checkout de Stripe", "POST", f"/api/Pagos/checkout/{oid}", accept_status=(302, 303))
    url = find_key(checkout.body, ["url", "checkoutUrl", "sessionUrl", "paymentUrl"], depth=2)
    sid = find_key(checkout.body, ["sessionId", "session_id", "id"], depth=2)
    if checkout.ok:
        if not (isinstance(url, str) and url.startswith("http")):
            r.report.add(Step("URL de checkout", "POST", "/api/Pagos/checkout/{guid}", checkout.status, "FALLA",
                              "la respuesta no trae una URL de Stripe que la app pueda abrir"))
        if isinstance(sid, str) and sid.startswith("cs_"):
            ctx.checkout_session_id = sid
    if ctx.checkout_session_id:
        r.call("Resultado de pago", "GET", f"/api/Pagos/resultado/{ctx.checkout_session_id}", optional=True)
        r.call("Retorno /pago/exitoso", "GET", "/pago/exitoso",
               query={"session_id": ctx.checkout_session_id}, optional=True, accept_status=(302, 303))
    else:
        r.report.skip("Resultado de pago", "GET", "/api/Pagos/resultado/{sessionId}", "sin sessionId de Stripe")
    r.call("Webhook de Stripe sin firma (debe rechazar)", "POST", "/api/Pagos/stripe/webhook",
           json_body={"type": "checkout.session.completed"}, token="", accept_status=(400, 401, 403))

    r.call("Cancelar orden", "POST", f"/api/Orden/{oid}/cancelar")
    r.call("Calificar al yonke", "POST", "/api/YonkesCalificaciones",
           json_body={"cotizacionGuidId": qid, "calificacion": 5, "comentario": "Prueba automática"},
           optional=True)
    if ctx.yonke_id:
        r.call("Calificaciones del yonke (cliente)", "GET", f"/api/YonkesCalificaciones/{ctx.yonke_id}",
               optional=True)


def run_cleanup(r: Runner, ctx: Context, args: argparse.Namespace) -> None:
    print("\n== 7. Limpieza ==")
    if args.keep:
        print("· --keep: se conservan los datos creados")
        return
    if ctx.client_token and ctx.request_id:
        r.api.token = ctx.client_token
        for guid in ctx.image_ids:
            r.call("Eliminar imagen", "DELETE", f"/api/SolicitudesImagenes/{guid}", optional=True)
        r.call("Eliminar todas las ciudades", "DELETE", f"/api/SolicitudCiudades/{ctx.request_id}/ciudades",
               optional=True)
        r.call("Cancelar solicitud", "DELETE", f"/api/Solicitudes/{ctx.request_id}",
               json_body={"guidId": ctx.request_id, "estatusId": None, "userId": ctx.client_user_id,
                          "notas": "Cancelada por api_full_test"})
    else:
        print("· nada que limpiar del cliente")
    if ctx.created_yonke_email and ctx.yonke_id and ctx.yonke_token:
        r.api.token = ctx.yonke_token
        r.call("Baja del yonke de prueba", "PUT", f"/api/Yonkes/baja/byGuidId/{ctx.yonke_id}", optional=True)


# --------------------------------------------------------------------------
# Programa principal
# --------------------------------------------------------------------------


def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base-url", default=os.environ.get("API_BASE_URL", DEFAULT_BASE_URL))
    p.add_argument("--phone", help="teléfono E.164 para el OTP del cliente")
    p.add_argument("--otp", help="código OTP si ya lo tienes (evita la consola)")
    p.add_argument("--client-token", help="JWT de cliente ya emitido")
    p.add_argument("--yonke-email")
    p.add_argument("--yonke-password")
    p.add_argument("--yonke-token", help="JWT de yonke ya emitido")
    p.add_argument("--yonke-id", help="guid del yonke si el login no lo devuelve")
    p.add_argument("--create-yonke", action="store_true", help="da de alta un yonke de prueba y lo usa")
    p.add_argument("--state-id", type=int)
    p.add_argument("--city-id", type=int)
    p.add_argument("--brand-id", type=int)
    p.add_argument("--model-id", type=int)
    p.add_argument("--quote-id", help="guid de una cotización existente para probar compra")
    p.add_argument("--request-yonke-id", help="guid de SolicitudYonkes para cotizar directamente")
    p.add_argument("--keep", action="store_true", help="no cancelar ni borrar lo creado")
    p.add_argument("--timeout", type=float, default=40.0)
    p.add_argument("--insecure", action="store_true", help="no verificar TLS (sólo pruebas locales)")
    p.add_argument("--report", default="api_full_test_report.json")
    return p.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    if args.yonke_email and not args.yonke_password and sys.stdin.isatty():
        args.yonke_password = getpass.getpass("Contraseña del yonke: ")
    api = Api(args.base_url, args.timeout, args.insecure)
    report = Report()
    runner = Runner(api, report)
    ctx = Context()

    print(f"Prueba total refaNet — servidor {args.base_url}")
    for stage in (
        run_catalogs,
        run_client_login,
        run_client_flow,
        run_yonke_login,
        run_yonke_flow,
        run_client_purchase,
        run_cleanup,
    ):
        try:
            stage(runner, ctx, args)
        except KeyboardInterrupt:
            print("\nInterrumpido.")
            break
        except Exception as err:  # noqa: BLE001 - un fallo de un paso no debe ocultar el resto
            report.add(Step(stage.__name__, "-", "-", 0, "FALLA", f"excepción interna: {err!r}"))

    ok = sum(1 for s in report.steps if s.outcome == "OK")
    skipped = sum(1 for s in report.steps if s.outcome == "OMITIDO")
    print("\n== Resumen ==")
    print(f"OK: {ok}   Avisos: {len(report.warnings)}   Fallas: {len(report.failures)}   Omitidos: {skipped}")
    for s in report.failures:
        print(f"  ✖ {s.name}: {s.method} {s.path} → {s.status or 'sin respuesta'}. {s.note}")
    for s in report.warnings:
        print(f"  △ {s.name}: {s.note}")

    with open(args.report, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "baseUrl": args.base_url,
                "fecha": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "resumen": {"ok": ok, "avisos": len(report.warnings), "fallas": len(report.failures), "omitidos": skipped},
                "pasos": [s.__dict__ for s in report.steps],
            },
            fh,
            ensure_ascii=False,
            indent=2,
        )
    print(f"Informe guardado en {args.report}")
    return 1 if report.failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
