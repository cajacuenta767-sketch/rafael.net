import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../data/client_yonkes_repository.dart';
import '../domain/client_yonke.dart';

const _navy = Color(0xFF082B50);
const _green = Color(0xFF49B927);
const _page = Color(0xFFFBFCFD);
const _muted = Color(0xFF68717E);

class ClientYonkesPage extends ConsumerStatefulWidget {
  const ClientYonkesPage({super.key, this.repository});

  final ClientYonkesRepository? repository;

  @override
  ConsumerState<ClientYonkesPage> createState() => _ClientYonkesPageState();
}

class _ClientYonkesPageState extends ConsumerState<ClientYonkesPage> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final ClientYonkesRepository _repository;
  Timer? _debounce;
  List<ClientYonke> _items = const [];
  ClientYonkeCity? _city;
  int _currentPage = 1;
  int _pageCount = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ref.read(clientYonkesRepositoryProvider);
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _load(reset: true);
    });
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 260 &&
        !_loading &&
        !_loadingMore &&
        _currentPage < _pageCount) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final requestedPage = reset ? 1 : _currentPage + 1;
    try {
      final result = await _repository.getPage(
        page: requestedPage,
        pageSize: _pageSize,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        cityId: _city?.id,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _currentPage = result.page;
        _pageCount = result.pageCount;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _chooseCity() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          _CityFilterSheet(repository: _repository, selected: _city),
    );
    if (!mounted || result == null) return;
    final selected = result is ClientYonkeCity ? result : null;
    if (selected == _city) return;
    setState(() => _city = selected);
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(
      backgroundColor: _page,
      surfaceTintColor: _page,
      centerTitle: true,
      title: const Text(
        'Explorar yonkes',
        style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
    ),
    body: RefreshIndicator(
      color: _green,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('yonke-search-input'),
                      controller: _search,
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar yonke...',
                        hintStyle: const TextStyle(color: Color(0xFF9AA1AA)),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF8B939D),
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                onPressed: () {
                                  _search.clear();
                                  _load(reset: true);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF3F5F6),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: _city != null,
                    backgroundColor: _green,
                    child: IconButton.filledTonal(
                      key: const Key('yonke-city-filter'),
                      tooltip: _city == null
                          ? 'Filtrar por ciudad'
                          : _city!.label,
                      onPressed: _chooseCity,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F5F6),
                        foregroundColor: _city == null ? _navy : _green,
                        minimumSize: const Size.square(50),
                      ),
                      icon: const Icon(Icons.filter_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_city != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(_city!.label),
                    onDeleted: () {
                      setState(() => _city = null);
                      _load(reset: true);
                    },
                  ),
                ),
              ),
            ),
          ..._content(),
        ],
      ),
    ),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: -1),
  );

  List<Widget> _content() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: _green)),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _DirectoryState(
            icon: Icons.cloud_off_outlined,
            title: 'No pudimos cargar los yonkes',
            message: 'Revisa tu conexión e inténtalo nuevamente.',
            action: OutlinedButton.icon(
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _DirectoryState(
            icon: Icons.storefront_outlined,
            title: 'No encontramos yonkes',
            message: 'Prueba otra búsqueda o elimina el filtro de ciudad.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        sliver: SliverList.separated(
          itemCount: _items.length,
          itemBuilder: (context, index) => _YonkeRow(
            yonke: _items[index],
            onOpen: () => context.push(
              AppRoutes.clientYonkeProfile(_items[index].id),
              extra: _items[index],
            ),
          ),
          separatorBuilder: (_, _) =>
              const Divider(height: 19, color: Color(0xFFE9ECEF)),
        ),
      ),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator(color: _green)),
          ),
        ),
    ];
  }
}

class ClientYonkeProfilePage extends ConsumerStatefulWidget {
  const ClientYonkeProfilePage({
    super.key,
    required this.initial,
    this.repository,
  });

  final ClientYonke initial;
  final ClientYonkesRepository? repository;

  @override
  ConsumerState<ClientYonkeProfilePage> createState() =>
      _ClientYonkeProfilePageState();
}

class _ClientYonkeProfilePageState
    extends ConsumerState<ClientYonkeProfilePage> {
  late final ClientYonkesRepository _repository;
  ClientYonkeDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ref.read(clientYonkesRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail = await _repository.getDetail(widget.initial);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final yonke = detail?.yonke ?? widget.initial;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: _page,
        centerTitle: true,
        title: const Text(
          'Perfil del yonke',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Center(child: _YonkeLogo(yonke: yonke, radius: 45)),
                const SizedBox(height: 12),
                Text(
                  yonke.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (yonke.location.isNotEmpty)
                  Text(
                    yonke.location,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted),
                  ),
                const SizedBox(height: 8),
                Center(child: _RatingLine(yonke: yonke)),
                const SizedBox(height: 22),
                _ProfileSection(
                  title: 'Información',
                  children: [
                    if (yonke.address != null)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: yonke.address!,
                      ),
                    if (yonke.phone != null)
                      _InfoRow(icon: Icons.phone_outlined, text: yonke.phone!),
                    if (yonke.email != null)
                      _InfoRow(icon: Icons.email_outlined, text: yonke.email!),
                    if (yonke.address == null &&
                        yonke.phone == null &&
                        yonke.email == null)
                      const Text(
                        'El API no proporcionó datos de contacto.',
                        style: TextStyle(color: _muted),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileSection(
                  title: 'Cobertura',
                  children: detail!.coverage.isEmpty
                      ? const [
                          Text(
                            'Cobertura no disponible.',
                            style: TextStyle(color: _muted),
                          ),
                        ]
                      : detail.coverage
                            .map(
                              (city) => _InfoRow(
                                icon: Icons.check_circle_outline,
                                text: city,
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 14),
                _ProfileSection(
                  title: 'Opiniones',
                  children: detail.ratingComments.isEmpty
                      ? const [
                          Text(
                            'Este yonke todavía no tiene comentarios.',
                            style: TextStyle(color: _muted),
                          ),
                        ]
                      : detail.ratingComments
                            .map(
                              (comment) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '“$comment”',
                                  style: const TextStyle(
                                    color: Color(0xFF303947),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                ),
              ],
            ),
    );
  }
}

class _YonkeRow extends StatelessWidget {
  const _YonkeRow({required this.yonke, required this.onOpen});

  final ClientYonke yonke;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _YonkeLogo(yonke: yonke, radius: 31),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              yonke.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (yonke.location.isNotEmpty)
              Text(
                yonke.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            const SizedBox(height: 3),
            _RatingLine(yonke: yonke),
          ],
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        key: Key('open-yonke-${yonke.id}'),
        onPressed: onOpen,
        style: OutlinedButton.styleFrom(
          foregroundColor: _green,
          side: const BorderSide(color: _green),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: const Text(
          'Ver perfil',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _YonkeLogo extends StatelessWidget {
  const _YonkeLogo({required this.yonke, required this.radius});

  final ClientYonke yonke;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: _navy,
    foregroundImage: yonke.logoUrl == null
        ? null
        : NetworkImage(yonke.logoUrl!),
    onForegroundImageError: yonke.logoUrl == null ? null : (_, _) {},
    child: Text(
      yonke.name.substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * .55,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.yonke});

  final ClientYonke yonke;

  @override
  Widget build(BuildContext context) {
    if (yonke.ratingCount == 0) {
      return const Text(
        'Sin calificaciones',
        style: TextStyle(color: _muted, fontSize: 12),
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: _green, size: 16),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${yonke.ratingAverage.toStringAsFixed(1)} (${yonke.ratingCount})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CityFilterSheet extends StatefulWidget {
  const _CityFilterSheet({required this.repository, required this.selected});

  final ClientYonkesRepository repository;
  final ClientYonkeCity? selected;

  @override
  State<_CityFilterSheet> createState() => _CityFilterSheetState();
}

class _CityFilterSheetState extends State<_CityFilterSheet> {
  late final Future<List<ClientYonkeCity>> _cities = widget.repository
      .getCities();
  String _query = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5D9DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrar por ciudad',
              style: TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase().trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar ciudad',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: const Text('Todas las ciudades'),
              trailing: widget.selected == null
                  ? const Icon(Icons.check, color: _green)
                  : null,
              onTap: () => Navigator.pop(context, const _ClearCitySelection()),
            ),
            Expanded(
              child: FutureBuilder<List<ClientYonkeCity>>(
                future: _cities,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: _green),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('No se pudieron cargar las ciudades.'),
                    );
                  }
                  final cities = (snapshot.data ?? const [])
                      .where(
                        (city) =>
                            _query.isEmpty ||
                            city.label.toLowerCase().contains(_query),
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: cities.length,
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(city.name),
                        subtitle: Text(city.state),
                        trailing: widget.selected?.id == city.id
                            ? const Icon(Icons.check, color: _green)
                            : null,
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClearCitySelection {
  const _ClearCitySelection();
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8EBEF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        ...children,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Icon(icon, color: _green, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF303947))),
        ),
      ],
    ),
  );
}

class _DirectoryState extends StatelessWidget {
  const _DirectoryState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(34),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 50, color: _green),
        const SizedBox(height: 13),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
