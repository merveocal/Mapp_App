// kişilerin favor yerleri, harita başlatılır başlatılmaz geliyor bu sorunu çözmedim kaldı

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../models/user.dart';
import '../models/position.dart';
import '../services/api_service.dart';
import 'package:map_app/utils/location_utils.dart';
import 'package:map_app/utils/color_utils.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final loc.Location location = loc.Location();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  double _zoom = 8.0;
  LatLng _markerPosition = LatLng(39.9876, 32.8654);
  List<LatLng> _markerPositions = [];
  List<LatLng> _selectedMarkers = [];
  List<LatLng> _measurementMarkers = [];
  List<LatLng> _customMarkers = [];

  List<Color> _markerColors = [];
  bool _isMeasuring = false;
  bool _isLoading = true;

  final Distance _distance = Distance();
  List<User> _users = [];
  int? _selectedUserId;
  List<Position> _positions = [];
  List<Position> _filteredPositions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _selectMarkerForMeasurement(LatLng markerPosition) {
    setState(() {
      bool alreadySelected = _selectedMarkers.any(
        (marker) => isSamePosition(marker, markerPosition),
      );

      if (alreadySelected) {
        _selectedMarkers.removeWhere(
          (marker) => isSamePosition(marker, markerPosition),
        );
      } else {
        _selectedMarkers.add(markerPosition);
      }

      if (_selectedMarkers.length > 2) {
        _selectedMarkers.removeAt(0);
      }
    });

    if (_selectedMarkers.length == 2) {
      final distance = _calculateDistance(
        _selectedMarkers[0],
        _selectedMarkers[1],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mesafe: ${distance.toStringAsFixed(2)} km',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _users = await ApiService.fetchUsers();
      _positions = await ApiService.fetchPositions();
      _filteredPositions = List.from(_positions);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<String?> _showAddUserDialog(BuildContext context) {
    final TextEditingController _nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Yeni Kişi Ekle'),
            content: TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Kişi ismi girin'),
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.pop(context, _nameController.text.trim()),
                child: const Text('Ekle'),
              ),
            ],
          ),
    );
  }

  Future<int?> _showDeleteUserDialog(BuildContext context) async {
    int? selectedUserId;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Silinecek Kullanıcıyı Seç'),
          content: DropdownButton<int>(
            value: selectedUserId,
            isExpanded: true,
            items:
                _users.map((user) {
                  return DropdownMenuItem<int>(
                    value: user.id,
                    child: Text(user.name),
                  );
                }).toList(),
            onChanged: (value) {
              selectedUserId = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(selectedUserId);
              },
              child: const Text('Sil'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'flutter_app'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final searchedPosition = LatLng(lat, lon);

          setState(() => _markerPosition = searchedPosition);
          _mapController.move(searchedPosition, 15);
        } else {
          _showSnackbar('Adres bulunamadı');
        }
      } else {
        _showSnackbar('Arama sırasında hata oluştu');
      }
    } catch (e) {
      _showSnackbar('Hata: $e');
    }
  }

  void _onMarkerTapped(LatLng markerLatLng) {
    setState(() {
      if (_selectedMarkers.any((m) => latLngEquals(m, markerLatLng))) {
        _selectedMarkers.removeWhere((m) => latLngEquals(m, markerLatLng));
      } else {
        _selectedMarkers.add(markerLatLng);
        if (_selectedMarkers.length > 2) {
          _selectedMarkers.removeAt(0);
        }
      }
    });

    if (_selectedMarkers.length == 2) {
      final distance = _calculateDistance(
        _selectedMarkers[0],
        _selectedMarkers[1],
      );
      _showSnackbar('Mesafe: ${distance.toStringAsFixed(2)} km');
    }
  }

  void _goToUserLocation() async {
    final current = await location.getLocation();
    final currentLatLng = LatLng(current.latitude!, current.longitude!);
    _mapController.move(currentLatLng, 15);
  }

  double _calculateDistance(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Kilometer, a, b);

  void _showSnackbar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Color _getMarkerColor(int userId) => getMarkerColor(userId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Harita Keşfet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on, color: Colors.white),
            onPressed: _goToUserLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
              color: const Color(0xFF2E7D32),
              child: const Text(
                'Menü',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Kişi Ekle'),
              onTap: () async {
                Navigator.pop(context); // Drawer’ı kapat
                final newName = await _showAddUserDialog(context);
                if (newName != null && newName.isNotEmpty) {
                  try {
                    await ApiService.addUser(newName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$newName adlı kullanıcı eklendi'),
                      ),
                    );
                    _loadData(); // Listeyi güncelle
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kullanıcı eklenemedi: $e')),
                    );
                  }
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Kişi Sil'),
              onTap: () async {
                Navigator.pop(context);
                final selectedUserId = await _showDeleteUserDialog(context);
                if (selectedUserId != null) {
                  await ApiService.deleteUser(selectedUserId);
                  _loadData(); // Listeyi güncelle
                }
              },
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // ✅ Adres Arama (80%)
                        Expanded(
                          flex: 7, // %80
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: "Adres ya da yer adı yazın",
                              hintStyle: TextStyle(fontSize: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF2E7D32),
                              ),
                              suffixIcon:
                                  _searchController.text.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed:
                                            () => setState(
                                              () => _searchController.clear(),
                                            ),
                                      )
                                      : null,
                            ),
                            onSubmitted: (_) => _searchAndNavigate(),
                          ),
                        ),

                        const SizedBox(width: 8), // Alanlar arası boşluk
                        // ✅ Kullanıcı Dropdown (20%)
                        if (_users.isNotEmpty)
                          Expanded(
                            flex: 3, // %20
                            child: DropdownButtonFormField<int>(
                              value: _selectedUserId,
                              decoration: InputDecoration(
                                hintText: 'User',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),

                              isExpanded: true,
                              items:
                                  _users.map((user) {
                                    return DropdownMenuItem<int>(
                                      value: user.id,
                                      child: Text(user.name),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedUserId = value;
                                  if (value == null) {
                                    _filteredPositions = _positions;
                                  } else {
                                    _filteredPositions =
                                        _positions
                                            .where((p) => p.userId == value)
                                            .toList();

                                    // Harita konum ortalaması
                                    double totalLat = 0.0;
                                    double totalLng = 0.0;
                                    int count = 0;

                                    for (var pos in _filteredPositions) {
                                      totalLat += pos.latitude;
                                      totalLng += pos.longitude;
                                      count++;
                                    }

                                    if (count > 0) {
                                      double avgLat = totalLat / count;
                                      double avgLng = totalLng / count;
                                      _mapController.move(
                                        LatLng(avgLat, avgLng),
                                        _zoom,
                                      );
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Harita
                  Expanded(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        center: _markerPosition,
                        zoom: _zoom,
                        interactiveFlags:
                            InteractiveFlag.pinchZoom | InteractiveFlag.drag,

                        onTap: (tapPosition, latLng) {
                          if (_isMeasuring) {
                            LatLng? nearestMarker;
                            double minDistance = double.infinity;

                            for (var position in _filteredPositions) {
                              final markerLatLng = LatLng(
                                position.latitude,
                                position.longitude,
                              );
                              double distance = _calculateDistance(
                                latLng,
                                markerLatLng,
                              );
                              if (distance < 0.1 && distance < minDistance) {
                                minDistance = distance;
                                nearestMarker = markerLatLng;
                              }
                            }

                            if (nearestMarker != null) {
                              _selectMarkerForMeasurement(nearestMarker);
                            }
                          } else {
                            setState(() {
                              _customMarkers.add(latLng);
                            });
                          }
                        },
                      ),

                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.sayac_proje',
                        ),

                        // Veritabanından gelen markerlar
                        MarkerLayer(
                          markers:
                              _filteredPositions.map((position) {
                                final markerLatLng = LatLng(
                                  position.latitude,
                                  position.longitude,
                                );
                                final isSelected = _selectedMarkers.contains(
                                  markerLatLng,
                                );

                                return Marker(
                                  width: 80,
                                  height: 80,
                                  point: markerLatLng,
                                  builder:
                                      (ctx) => GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_isMeasuring) {
                                              if (_measurementMarkers.length >=
                                                  2) {
                                                _measurementMarkers.clear();
                                              }
                                              _measurementMarkers.add(
                                                markerLatLng,
                                              );
                                            } else {
                                              // Ölçüm modu kapalıysa sadece bilgi göster
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${position.name}\nKonum: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        },

                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border:
                                                isSelected
                                                    ? Border.all(
                                                      color: Colors.blue,
                                                      width: 3,
                                                    )
                                                    : null,
                                            boxShadow:
                                                isSelected
                                                    ? [
                                                      BoxShadow(
                                                        color: Colors.blue
                                                            .withOpacity(0.5),
                                                        spreadRadius: 2,
                                                        blurRadius: 5,
                                                      ),
                                                    ]
                                                    : null,
                                          ),
                                          child: Icon(
                                            Icons.location_pin,
                                            size:
                                                _selectedMarkers.any(
                                                      (m) => latLngEquals(
                                                        m,
                                                        markerLatLng,
                                                      ),
                                                    )
                                                    ? 45
                                                    : 40,
                                            color:
                                                _selectedMarkers.any(
                                                      (m) => latLngEquals(
                                                        m,
                                                        markerLatLng,
                                                      ),
                                                    )
                                                    ? Colors.blue
                                                    : _getMarkerColor(
                                                      position.userId,
                                                    ),
                                          ),
                                        ),
                                      ),
                                );
                              }).toList(),
                        ),
                        MarkerLayer(
                          markers:
                              _customMarkers.map((latLng) {
                                return Marker(
                                  width: 80,
                                  height: 80,
                                  point: latLng,
                                  builder:
                                      (ctx) => GestureDetector(
                                        onLongPress: () {
                                          setState(() {
                                            _customMarkers.remove(latLng);
                                          });
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("Marker silindi"),
                                            ),
                                          );
                                        },
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                );
                              }).toList(),
                        ),

                        // Mesafe gösterimi
                        if (_selectedMarkers.length == 2)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 200,
                                height: 50,
                                point: LatLng(
                                  (_selectedMarkers[0].latitude +
                                          _selectedMarkers[1].latitude) /
                                      2,
                                  (_selectedMarkers[0].longitude +
                                          _selectedMarkers[1].longitude) /
                                      2,
                                ),
                                builder:
                                    (ctx) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${_calculateDistance(_selectedMarkers[0], _selectedMarkers[1]).toStringAsFixed(2)} km',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                _zoom = (_zoom + 1).clamp(1.0, 18.0);
              });
              _mapController.move(_mapController.center, _zoom);
            },
            child: const Icon(Icons.zoom_in, size: 30, color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                _zoom = (_zoom - 1).clamp(1.0, 18.0);
              });
              _mapController.move(_mapController.center, _zoom);
            },
            child: const Icon(Icons.zoom_out, size: 30, color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'current_location',
            mini: true,
            backgroundColor: Colors.blue,
            onPressed: _goToUserLocation,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
