import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'legal_docs_screen.dart';

class TicketsScreen extends StatefulWidget {
  final String initialTransportType; // 'all', 'flight', 'train'

  const TicketsScreen({super.key, this.initialTransportType = 'all'});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _transportType = 'all'; // 'all', 'flight', 'train'
  String _departureCity = 'Алматы';
  String _arrivalCity = 'Астана';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _passengersCount = 1;
  final String _seatClass = 'all';
  bool _directOnly = false;
  bool _hasBaggage = false;

  bool _isLoading = false;
  String? _errorMessage;
  List<TicketFlight> _flights = [];
  List<CityOption> _cities = [];

  // Вкладка "Мои билеты"
  List<TicketBooking> _myBookings = [];
  bool _loadingMyBookings = false;

  @override
  void initState() {
    super.initState();
    _transportType = widget.initialTransportType;
    _tabController = TabController(length: 2, vsync: this);
    _loadCities();
    _searchTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final cities = await ApiService.getTicketCities();
    if (mounted && cities.isNotEmpty) {
      setState(() => _cities = cities);
    }
  }

  Future<void> _searchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final results = await ApiService.searchTickets(
      departureCity: _departureCity,
      arrivalCity: _arrivalCity,
      date: dateStr,
      transportType: _transportType,
      seatClass: _seatClass,
      directOnly: _directOnly,
      hasBaggage: _hasBaggage,
    );

    if (!mounted) return;
    setState(() {
      _flights = results;
      _isLoading = false;
      if (results.isEmpty) {
        _errorMessage = 'Рейсов по выбранному маршруту не найдено. Попробуйте изменить даты или города.';
      }
    });
  }

  Future<void> _loadMyBookings() async {
    setState(() => _loadingMyBookings = true);
    final bookings = await ApiService.getMyTicketBookings();
    if (!mounted) return;
    setState(() {
      _myBookings = bookings;
      _loadingMyBookings = false;
    });
  }

  void _swapCities() {
    setState(() {
      final temp = _departureCity;
      _departureCity = _arrivalCity;
      _arrivalCity = temp;
    });
    _searchTickets();
  }

  void _openBookingSheet(TicketFlight flight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TicketBookingSheet(
        flight: flight,
        passengersCount: _passengersCount,
        onBooked: (booking) {
          _searchTickets();
          _loadMyBookings();
          _tabController.animateTo(1); // Переключить на "Мои билеты"
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Билеты: Авиа & ЖД', style: AppText.sora(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text('Прямые рейсы, чартеры и поезда «Тальго»', style: AppText.work(size: 11.5, color: AppColors.muted)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          labelStyle: AppText.sora(size: 13, weight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Поиск билетов'),
            Tab(text: 'Мои билеты'),
          ],
          onTap: (idx) {
            if (idx == 1) _loadMyBookings();
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА: ПОИСК БИЛЕТОВ ====================

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Карточка параметров поиска
        _buildSearchCard(),
        const SizedBox(height: 16),

        // Заголовок выдачи
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Найдено вариантов: ${_flights.length}',
              style: AppText.sora(size: 14.5, weight: FontWeight.w700),
            ),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.flight_takeoff_rounded, size: 40, color: AppColors.muted),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppText.work(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _departureCity = 'Алматы';
                      _arrivalCity = 'Астана';
                      _transportType = 'all';
                    });
                    _searchTickets();
                  },
                  child: const Text('Сбросить фильтры', style: TextStyle(color: AppColors.teal)),
                ),
              ],
            ),
          )
        else
          for (final flight in _flights) ...[
            _buildFlightCard(flight),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Переключатель типа транспорта (Авиа / ЖД / Все)
          Row(
            children: [
              _transportPill(label: 'Все', value: 'all', icon: Icons.all_inclusive_rounded),
              const SizedBox(width: 8),
              _transportPill(label: 'Авиабилеты', value: 'flight', icon: Icons.flight_rounded),
              const SizedBox(width: 8),
              _transportPill(label: 'ЖД билеты', value: 'train', icon: Icons.train_rounded),
            ],
          ),
          const SizedBox(height: 14),

          // Выбор Откуда ⇄ Куда
          Row(
            children: [
              Expanded(
                child: _citySelectBox(
                  label: 'Откуда',
                  value: _departureCity,
                  onChanged: (val) {
                    setState(() => _departureCity = val);
                    _searchTickets();
                  },
                ),
              ),
              IconButton(
                onPressed: _swapCities,
                icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.teal, size: 26),
                tooltip: 'Поменять местами',
              ),
              Expanded(
                child: _citySelectBox(
                  label: 'Куда',
                  value: _arrivalCity,
                  onChanged: (val) {
                    setState(() => _arrivalCity = val);
                    _searchTickets();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Выбор даты и количества пассажиров
          Row(
            children: [
              // Дата
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.teal),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Дата поездки', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                            Text(
                              DateFormat('d MMMM, EE', 'ru').format(_selectedDate),
                              style: AppText.work(size: 12.5, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Пассажиры
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Пассажиры', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                          Text('$_passengersCount чел.', style: AppText.work(size: 12.5, weight: FontWeight.w600)),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: _passengersCount > 1 ? () => setState(() => _passengersCount--) : null,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.teal),
                            ),
                          ),
                          InkWell(
                            onTap: _passengersCount < 9 ? () => setState(() => _passengersCount++) : null,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.teal),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Чекбоксы: Только прямые, С багажом
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _directOnly = !_directOnly);
                  _searchTickets();
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _directOnly,
                      activeColor: AppColors.teal,
                      onChanged: (val) {
                        setState(() => _directOnly = val ?? false);
                        _searchTickets();
                      },
                    ),
                    const Text('Прямой рейс', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() => _hasBaggage = !_hasBaggage);
                  _searchTickets();
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _hasBaggage,
                      activeColor: AppColors.teal,
                      onChanged: (val) {
                        setState(() => _hasBaggage = val ?? false);
                        _searchTickets();
                      },
                    ),
                    const Text('С багажом', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _searchTickets,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Найти билеты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportPill({required String label, required String value, required IconData icon}) {
    final selected = _transportType == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _transportType = value);
          _searchTickets();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : AppColors.sand,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.teal : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _citySelectBox({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final defaultCities = ['Алматы', 'Астана', 'Шымкент', 'Актау', 'Анталья', 'Дубай', 'Стамбул'];
    final cityList = _cities.isNotEmpty ? _cities.map((c) => c.city).toList() : defaultCities;
    if (!cityList.contains(value)) {
      cityList.add(value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.teal, size: 20),
              style: AppText.sora(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
              items: cityList
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _searchTickets();
    }
  }

  Widget _buildFlightCard(TicketFlight flight) {
    final isTrain = flight.transportType == 'train';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Перевозчик, номер рейса и плашка транспорта
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isTrain
                      ? const Color(0xFF1565C0).withValues(alpha: 0.12)
                      : AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTrain ? Icons.train_rounded : Icons.flight_rounded,
                  color: isTrain ? const Color(0xFF1565C0) : AppColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flight.carrierName, style: AppText.sora(size: 13.5, weight: FontWeight.w700)),
                    Text(
                      '${flight.flightNumber} • ${flight.aircraftOrTrainModel ?? (isTrain ? "Поезд" : "Самолет")}',
                      style: AppText.work(size: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (flight.availableSeats <= 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Осталось ${flight.availableSeats} мест!',
                    style: const TextStyle(color: AppColors.coral, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Маршрут: Время вылета --- Длительность ---> Время прилёта
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Вылет
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flight.departureTimeFormatted, style: AppText.sora(size: 18, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(flight.departureCity, style: AppText.work(size: 12, weight: FontWeight.w600)),
                  Text(flight.departureAirport, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),

              // Стрелка и длительность
              Column(
                children: [
                  Text(flight.durationFormatted, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 28, height: 1.5, color: AppColors.border),
                      Icon(
                        isTrain ? Icons.train_rounded : Icons.flight_takeoff_rounded,
                        size: 14,
                        color: AppColors.teal,
                      ),
                      Container(width: 28, height: 1.5, color: AppColors.border),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flight.isDirect ? 'Прямой' : '${flight.stopsCount} пересадка',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: flight.isDirect ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Прилёт
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(flight.arrivalTimeFormatted, style: AppText.sora(size: 18, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(flight.arrivalCity, style: AppText.work(size: 12, weight: FontWeight.w600)),
                  Text(flight.arrivalAirport, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Детали багажа и удобства
          Row(
            children: [
              Icon(
                flight.baggageIncluded ? Icons.luggage_rounded : Icons.no_luggage_outlined,
                size: 14,
                color: flight.baggageIncluded ? const Color(0xFF2E7D32) : AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                flight.baggageIncluded ? 'Багаж ${flight.baggageWeightKg} кг' : 'Без багажа',
                style: TextStyle(
                  fontSize: 11,
                  color: flight.baggageIncluded ? const Color(0xFF2E7D32) : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.backpack_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('Ручная кладь ${flight.handLuggageKg} кг', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const Spacer(),
              Text(
                'Класс: ${flight.seatClass.toUpperCase()}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.teal, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),

          // Цена и кнопка покупки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flight.price} ₸',
                    style: AppText.sora(size: 18, weight: FontWeight.w800, color: AppColors.coral),
                  ),
                  Text(
                    'от ${(flight.price / 12).round()} ₸/мес (0-0-12)',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _openBookingSheet(flight),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Выбрать билет', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА: МОИ БИЛЕТЫ ====================

  Widget _buildMyTicketsTab() {
    if (_loadingMyBookings) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    if (_myBookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.airplane_ticket_outlined, size: 54, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('У вас пока нет купленных билетов', style: AppText.sora(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Все оформленные авиабилеты и маршрутные квитанции ЖД будут сохранены здесь.',
                textAlign: TextAlign.center,
                style: AppText.work(size: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Найти билеты', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _myBookings.length,
      itemBuilder: (ctx, idx) {
        final b = _myBookings[idx];
        return _buildTicketVoucherCard(b);
      },
    );
  }

  Widget _buildTicketVoucherCard(TicketBooking booking) {
    final flight = booking.flight;
    final isTrain = flight?.transportType == 'train';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Шапка билета
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTrain ? const Color(0xFF1565C0) : AppColors.teal,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isTrain ? Icons.train_rounded : Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isTrain ? 'Электронный ЖД билет' : 'Электронный авиабилет',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ОПЛАЧЕНО',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Номер билета и рейс
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Номер билета', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        Text(booking.ticketNumber, style: AppText.sora(size: 13, weight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Рейс / Поезд', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        Text(flight?.flightNumber ?? 'KC-853', style: AppText.sora(size: 13, weight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Маршрут
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(flight?.departureCity ?? 'Алматы', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.teal, size: 18),
                    Text(flight?.arrivalCity ?? 'Астана', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),

                // Места и пассажир
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Пассажир', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        Text(booking.customerName, style: AppText.work(size: 12.5, weight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Место', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        Text(booking.seatNumbers ?? '14A', style: AppText.sora(size: 12.5, weight: FontWeight.w700, color: AppColors.teal)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Оплата и кнопка
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${booking.totalPrice} ₸',
                      style: AppText.sora(size: 16, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Маршрутная квитанция #${booking.ticketNumber} готова к печати'),
                            backgroundColor: AppColors.teal,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.teal),
                      label: const Text('Маршрут-квитанция', style: TextStyle(fontSize: 12, color: AppColors.teal)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.teal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketBookingSheet extends StatefulWidget {
  final TicketFlight flight;
  final int passengersCount;
  final ValueChanged<TicketBooking> onBooked;

  const _TicketBookingSheet({
    required this.flight,
    required this.passengersCount,
    required this.onBooked,
  });

  @override
  State<_TicketBookingSheet> createState() => _TicketBookingSheetState();
}

class _TicketBookingSheetState extends State<_TicketBookingSheet> {
  final _nameCtrl = TextEditingController(text: 'Айгерим Касымова');
  final _phoneCtrl = TextEditingController(text: '+7 701 555 12 34');
  final _emailCtrl = TextEditingController(text: 'aigerim@mail.kz');
  final _docCtrl = TextEditingController(text: '010203500891');

  String _paymentMethod = 'Kaspi Pay';
  bool _isSubmitting = false;
  bool _termsAccepted = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final doc = _docCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || doc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните все данные пассажира')),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для оформления билета требуется подтвердить согласие с Правилами перевозки и обработкой ПДН'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await ApiService.bookTicket(
      flightId: widget.flight.id,
      customerName: name,
      customerPhone: phone,
      customerEmail: email,
      documentNumber: doc,
      passengersCount: widget.passengersCount,
      paymentMethod: _paymentMethod,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res != null) {
      widget.onBooked(res);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Билет #${res.ticketNumber} успешно оплачен! Места: ${res.seatNumbers}'),
          backgroundColor: AppColors.teal,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось оформить билет. Попробуйте еще раз.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.flight.price * widget.passengersCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Бронирование и оплата билета', style: AppText.sora(size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              '${widget.flight.carrierName} • ${widget.flight.departureCity} ➔ ${widget.flight.arrivalCity}',
              style: AppText.work(size: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 16),

            // Данные пассажира
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ФИО пассажира (как в документе)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _docCtrl,
              decoration: const InputDecoration(
                labelText: 'ИИН или номер паспорта',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email для билета',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Способ оплаты
            Text('Способ оплаты:', style: AppText.sora(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _paymentChip('Kaspi Pay (QR)', 'Kaspi Pay', const Color(0xFFF14635)),
                _paymentChip('Карта Visa/MC', 'Банковская карта', const Color(0xFF1E3A8A)),
                _paymentChip('Halyk QR', 'Halyk Bank', const Color(0xFF007A33)),
              ],
            ),
            const SizedBox(height: 18),

            // Итого к оплате
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('К оплате (${widget.passengersCount} пасс.):', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      Text('$total ₸', style: AppText.sora(size: 18, weight: FontWeight.w800, color: AppColors.coral)),
                    ],
                  ),
                  const Text('0% комиссии', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _termsAccepted ? const Color(0xFFF8FAFC) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _termsAccepted ? AppColors.border : const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _termsAccepted,
                      activeColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11, color: AppColors.ink, height: 1.4),
                          children: [
                            const TextSpan(text: 'Согласен(на) с '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LegalDocsScreen(initialDoc: LegalDocType.aviation)),
                                ),
                                child: const Text(
                                  'Правилами перевозки (Приказ № 540)',
                                  style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 11),
                                ),
                              ),
                            ),
                            const TextSpan(text: ', условиями невозвратных тарифов и '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LegalDocsScreen(initialDoc: LegalDocType.privacy)),
                                ),
                                child: const Text(
                                  'обработкой ПДН',
                                  style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 11),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' по закону РК № 94-V.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                title: _isSubmitting ? 'Оформление...' : 'Оплатить $total ₸',
                onTap: _isSubmitting ? () {} : _submitBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(String title, String value, Color color) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? color : AppColors.ink,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
