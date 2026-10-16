import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generate browsable evidence and traceability from actual captures',
    () async {
      final root = Directory('build/responsive');
      if (!root.existsSync()) {
        return;
      }
      final files = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList();
      final byFolder = <String, List<File>>{};
      for (final file in files) {
        byFolder.putIfAbsent(file.parent.path, () => []).add(file);
      }
      final entries = <Map<String, Object>>[];
      final screenNames = RegExp(r"^\s+'(\d{2}_[a-z_]+)':", multiLine: true)
          .allMatches(
            File('test/app_gallery_capture_test.dart').readAsStringSync(),
          )
          .map((match) => match.group(1)!)
          .toSet();
      expect(screenNames.length, 39);
      for (final file in files) {
        final relative = file.path
            .substring(root.path.length + 1)
            .replaceAll('\\', '/');
        final parts = relative.split('/');
        final name = parts.last.replaceAll('.png', '');
        if (!screenNames.contains(name)) {
          continue;
        }
        if (!RegExp(r'^\d{2}_[a-z_]+$').hasMatch(name) ||
            name.contains('_fallo_') ||
            name.endsWith('_rotacion') ||
            name.endsWith('_acciones') ||
            name.endsWith('_editor') ||
            name.endsWith('_contacto') ||
            name.endsWith('_simulado')) {
          continue;
        }
        if (!parts.first.startsWith('dispositivos') &&
            !parts.first.startsWith('matrix') &&
            !parts.first.startsWith('limites') &&
            ![
              '320x480',
              '480x320',
              'estados',
              'accesibilidad',
              'contenido_largo',
              'largo200',
              'errores',
              'vacios',
              'fotos',
              'texto130_recorte',
              'texto150_recorte',
              'texto200_tablet',
            ].contains(parts.first)) {
          continue;
        }
        final folder = parts.take(parts.length - 1).join('/');
        final states =
            byFolder[file.parent.path]!
                .where(
                  (candidate) =>
                      candidate.path
                          .substring(candidate.parent.path.length + 1)
                          .startsWith('${name}_') &&
                      !candidate.path.contains('_fallo_') &&
                      !candidate.lastModifiedSync().isBefore(
                        file.lastModifiedSync(),
                      ),
                )
                .map(
                  (candidate) => candidate.path
                      .substring(root.path.length + 1)
                      .replaceAll('\\', '/'),
                )
                .toList()
              ..sort();
        final metadataFile = File(file.path.replaceAll('.png', '.json'));
        final metadata = metadataFile.existsSync()
            ? jsonDecode(metadataFile.readAsStringSync())
                  as Map<String, dynamic>
            : <String, dynamic>{'kind': 'legacy'};
        entries.add({
          'viewport': metadata,
          'profile': folder,
          'screen': name,
          'role': name.contains('_yonke_')
              ? 'Yonke'
              : name.contains('_cliente_')
              ? 'Cliente'
              : 'Acceso',
          'image': relative,
          'states': states,
          'captured': true,
          'visual': 'pendiente de revisión individual',
          'functional': 'ver suite; no certificado por dispositivo',
          'environment': 'Flutter widget test; no hardware',
          'timestamp': file.lastModifiedSync().toUtc().toIso8601String(),
        });
      }
      entries.sort(
        (a, b) => '${a['profile']}/${a['screen']}'.compareTo(
          '${b['profile']}/${b['screen']}',
        ),
      );
      await File('${root.path}/manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(entries));
      final csv = StringBuffer(
        'perfil,pantalla,rol,capturado,revision_visual,funcional,entorno,evidencia\n',
      );
      for (final entry in entries) {
        csv.writeln(
          [
                entry['profile'],
                entry['screen'],
                entry['role'],
                'si',
                'pendiente individual',
                'suite separada',
                'widget simulado',
                entry['image'],
              ]
              .map((value) => '"${value.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }
      await File('${root.path}/seguimiento.csv').writeAsString(csv.toString());
      final html =
          '''<!doctype html>
<html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>REFANET · Revisión de tamaños</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f5f7fa;color:#102e53;font:16px system-ui}
header{padding:24px;background:#102e53;color:white}h1{margin:0 0 8px;font-size:26px}p{line-height:1.5}
nav{padding:16px;display:flex;gap:12px;flex-wrap:wrap;background:white;border-bottom:1px solid #dde4eb}
select,input,button{font:inherit;min-height:44px;padding:8px 12px;max-width:100%;border:1px solid #bac8d7;border-radius:8px}
main{padding:20px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr));gap:20px;max-width:1600px;margin:auto}
article{border:1px solid #dde4eb;border-radius:12px;background:white;padding:16px;min-width:0}
article h2{font-size:18px;overflow-wrap:anywhere}article img{width:100%;height:260px;object-fit:contain;background:#edf2f7}
small{display:block;color:#63758a;margin:10px 0}details a{display:block;padding:8px;overflow-wrap:anywhere}
#count{padding:0 20px}a{color:#1555a3}dialog{width:96vw;max-width:none;height:94vh;max-height:none;padding:16px;border:1px solid #bac8d7;border-radius:12px}
dialog::backdrop{background:#0009}.toolbar{display:flex;flex-wrap:wrap;gap:12px;align-items:center}
#stage{overflow:auto;height:calc(100% - 120px);background:#e4eaf1;margin-top:12px;padding:12px}#full{display:block;max-width:none;margin:0 auto}
</style>
<header><h1>REFANET · Revisión de tamaños</h1>
<p>Perfiles representativos: tamaño lógico de ventana + densidad. No son fotografías ni certificaciones de dispositivos físicos.</p>
<p>Las miniaturas solo sirven para localizar apartados. Abre «Revisar al 100 %» para evaluar texto y controles. Las pruebas antiguas no se consideran aprobadas.</p></header>
<nav><label><input id="stress" type="checkbox"> Incluir pruebas extremas / antiguas</label>
<select id="profile" aria-label="Perfil de ventana"></select><select id="role" aria-label="Rol"><option value="">Todos los roles</option><option>Cliente</option><option>Yonke</option><option>Acceso</option></select>
<input id="search" placeholder="Buscar apartado" aria-label="Buscar apartado"><button id="prev">Anterior</button><button id="next">Siguiente</button><a href="seguimiento.csv">Seguimiento CSV</a></nav>
<p id="count"></p><main id="cards"></main>
<dialog id="viewer"><div class="toolbar"><button id="close">Cerrar</button><button id="actual">100 % lógico</button><button id="fit">Ajustar a ventana</button><a id="original" target="_blank">Abrir PNG</a></div><p id="dimensions"></p><div id="stage"><img id="full" alt=""></div></dialog>
<script>
const evidence=${jsonEncode(entries).replaceAll('<', r'\u003c')};
const profile=document.querySelector('#profile'),role=document.querySelector('#role'),search=document.querySelector('#search'),cards=document.querySelector('#cards'),stress=document.querySelector('#stress'),viewer=document.querySelector('#viewer'),full=document.querySelector('#full');
let page=0,current=null;
function available(){return evidence.filter(e=>stress.checked||e.viewport.kind==='representative')}
function profiles(){const previous=profile.value||new URLSearchParams(location.search).get('profile');profile.replaceChildren();for(const p of [...new Set(available().map(e=>e.profile))]){const o=document.createElement('option');o.value=p;o.textContent=p.replace('dispositivos/','');profile.append(o)}if([...profile.options].some(o=>o.value===previous))profile.value=previous}
function dimensions(e){const v=e.viewport;if(!v.logicalWidth)return 'Prueba antigua: densidad y captura sin metadatos verificables';return v.logicalWidth+' × '+v.logicalHeight+' lógicos · DPR '+v.dpr+' · texto '+Math.round((v.textScale||1)*100)+' % · '+v.physicalWidth+' × '+v.physicalHeight+' físicos · PNG '+v.captureWidth+' × '+v.captureHeight}
function actual(){full.style.width=(current.viewport.logicalWidth||full.naturalWidth)+'px'}
function open(e){current=e;full.src=e.image;full.alt=e.screen;document.querySelector('#original').href=e.image;document.querySelector('#dimensions').textContent=dimensions(e)+' · datos sintéticos; revisión visual pendiente';viewer.showModal();actual()}
document.querySelector('#close').onclick=()=>viewer.close();document.querySelector('#actual').onclick=actual;
document.querySelector('#fit').onclick=()=>{full.style.width=Math.min(current.viewport.logicalWidth||full.naturalWidth,document.querySelector('#stage').clientWidth-24)+'px'};
function render(){const filtered=available().filter(e=>e.profile===profile.value&&(!role.value||e.role===role.value)&&e.screen.includes(search.value.toLowerCase().replaceAll(' ','_')));const pages=Math.max(1,Math.ceil(filtered.length/39));page=Math.max(0,Math.min(page,pages-1));cards.replaceChildren();document.querySelector('#count').textContent=filtered.length+' apartados · página '+(page+1)+'/'+pages+' · sin aprobación visual automática';
for(const e of filtered.slice(page*39,(page+1)*39)){const article=document.createElement('article'),h=document.createElement('h2'),img=document.createElement('img'),small=document.createElement('small'),button=document.createElement('button');h.textContent=e.screen.replaceAll('_',' ');img.src=e.image;img.alt=h.textContent;img.loading='lazy';small.textContent=dimensions(e);button.textContent='Revisar al 100 %';button.onclick=()=>open(e);article.append(h,img,small,button);if(e.states.length){const d=document.createElement('details'),s=document.createElement('summary');s.textContent=e.states.length+' capturas de desplazamiento / estados';d.append(s);for(const path of e.states){const link=document.createElement('a');link.href=path;link.target='_blank';link.textContent=path.split('/').pop();d.append(link)}article.append(d)}cards.append(article)}
document.querySelector('#prev').disabled=page===0;document.querySelector('#next').disabled=page>=pages-1}
for(const input of [profile,role,search])input.addEventListener('input',()=>{page=0;render()});
stress.onchange=()=>{page=0;profiles();render()};
document.querySelector('#prev').onclick=()=>{page--;render()};document.querySelector('#next').onclick=()=>{page++;render()};profiles();render();
</script></html>''';
      await File('${root.path}/index.html').writeAsString(html);
      expect(entries, isNotEmpty);
    },
  );
}
