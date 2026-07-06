// ═════════════════════════════════════════════════════════════════
// reproductor_video.dart — Aspirantes ITVH
//
// Pantalla de reproducción de video a pantalla completa. Se abre
// desde el ícono de play en el carrusel de una publicación.
//
// Cambios (v2):
//   • Se reemplazó VideoProgressIndicator (el widget genérico del
//     paquete video_player) por _BarraProgreso, una barra hecha a
//     mano que SÍ da feedback visual al tocarla:
//       - En reposo es delgada (4px).
//       - Al tocar/arrastrar crece a 8px con una animación corta
//         (AnimatedContainer) y aparece un thumb (círculo blanco).
//       - Mientras arrastras, el thumb sigue el dedo en vivo y el
//         seek se calcula sobre la marcha; el seekTo() real al
//         controller solo se dispara al soltar, para no saturar
//         al video_player con seeks constantes.
//       - Los controles (ícono central + tiempos) NO se ocultan
//         mientras el usuario está arrastrando la barra, aunque
//         hayan pasado los 3 segundos normales.
//   • Contador de tiempo actual / duración total sigue viniendo de
//     ValueListenableBuilder sobre el controller (ya es un
//     ValueNotifier<VideoPlayerValue>, no hace falta Timer manual).
//   • El ícono de play/pause al centro funciona igual que antes:
//     se oculta unos segundos después de reproducir y reaparece al
//     tocar la pantalla.
// ═════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

class ReproductorVideo extends StatefulWidget {
  final String url;

  const ReproductorVideo({super.key, required this.url});

  @override
  State<ReproductorVideo> createState() => _ReproductorVideoState();
}

class _ReproductorVideoState extends State<ReproductorVideo> {
  late final VideoPlayerController _controller;
  bool _listo = false;
  bool _mostrarControles = true;
  bool _arrastrandoBarra = false;
  Timer? _timerOcultarControles;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _listo = true);
        _controller.play();
        _programarOcultarControles();
      });
  }

  @override
  void dispose() {
    _timerOcultarControles?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _programarOcultarControles() {
    _timerOcultarControles?.cancel();
    _timerOcultarControles = Timer(const Duration(seconds: 3), () {
      // No ocultar si está en pausa o si el usuario sigue arrastrando
      // la barra de progreso.
      if (!mounted || !_controller.value.isPlaying || _arrastrandoBarra) {
        return;
      }
      setState(() => _mostrarControles = false);
    });
  }

  void _alTocarPantalla() {
    setState(() => _mostrarControles = !_mostrarControles);
    if (_mostrarControles) _programarOcultarControles();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _timerOcultarControles?.cancel();
        _mostrarControles = true;
      } else {
        _controller.play();
        _programarOcultarControles();
      }
    });
  }

  // Se llama cuando el usuario empieza a arrastrar la barra: forzamos
  // que los controles estén visibles y cancelamos el auto-hide.
  void _alIniciarArrastre() {
    _timerOcultarControles?.cancel();
    setState(() {
      _arrastrandoBarra = true;
      _mostrarControles = true;
    });
  }

  // Se llama al soltar: si el video sigue en play, reprogramamos el
  // auto-hide normal.
  void _alTerminarArrastre() {
    setState(() => _arrastrandoBarra = false);
    if (_controller.value.isPlaying) _programarOcultarControles();
  }

  String _formatearDuracion(Duration d) {
    final minutos = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _listo
            ? GestureDetector(
          onTap: _alTocarPantalla,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),

              // Ícono central de play/pause — visible solo cuando
              // _mostrarControles es true (siempre visible en pausa).
              AnimatedOpacity(
                opacity: _mostrarControles ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_mostrarControles,
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.value.isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Barra de progreso + tiempos, siempre pegada abajo del
              // video. Se atenúa junto con el resto de los controles,
              // pero mientras el usuario arrastra, se fuerza visible
              // (ver _alIniciarArrastre).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _mostrarControles ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BarraProgreso(
                          controller: _controller,
                          onIniciarArrastre: _alIniciarArrastre,
                          onTerminarArrastre: _alTerminarArrastre,
                        ),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _controller,
                          builder: (context, valor, __) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatearDuracion(valor.position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  _formatearDuracion(valor.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// _BarraProgreso — barra de progreso interactiva estilo TikTok/IG.
//
// Reemplaza a VideoProgressIndicator. Se dibuja a mano con un
// GestureDetector + LayoutBuilder para conocer el ancho disponible
// y así convertir la posición horizontal del dedo en un porcentaje
// de la duración total.
//
// Comportamiento:
//   • En reposo: barra delgada (4px), sin thumb visible.
//   • Al tocar (onTapDown) o empezar a arrastrar (onHorizontalDragStart):
//     crece a 8px (AnimatedContainer) y aparece el thumb.
//   • Mientras se arrastra: el thumb sigue el dedo en vivo usando un
//     estado local (_arrastreLocal), SIN llamar a seekTo() en cada
//     frame — eso evita saturar al video_player con seeks.
//   • Al soltar (onHorizontalDragEnd / onTapUp): se dispara el
//     seekTo() real con la posición final y la barra vuelve a 4px.
// ═════════════════════════════════════════════════════════════════
class _BarraProgreso extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onIniciarArrastre;
  final VoidCallback onTerminarArrastre;

  const _BarraProgreso({
    required this.controller,
    required this.onIniciarArrastre,
    required this.onTerminarArrastre,
  });

  @override
  State<_BarraProgreso> createState() => _BarraProgresoState();
}

class _BarraProgresoState extends State<_BarraProgreso> {
  // Cuando no es null, el usuario está arrastrando y este valor
  // (0.0 a 1.0) manda sobre la posición real del controller para
  // pintar la barra y el thumb sin esperar al seek real.
  double? _arrastreLocal;

  double _fraccionActual(VideoPlayerValue valor) {
    if (_arrastreLocal != null) return _arrastreLocal!;
    final duracionMs = valor.duration.inMilliseconds;
    if (duracionMs == 0) return 0;
    return (valor.position.inMilliseconds / duracionMs).clamp(0.0, 1.0);
  }

  void _actualizarDesdeToque(double dx, double anchoTotal) {
    final fraccion = (dx / anchoTotal).clamp(0.0, 1.0);
    setState(() => _arrastreLocal = fraccion);
  }

  void _confirmarSeek() {
    final duracion = widget.controller.value.duration;
    if (_arrastreLocal != null && duracion.inMilliseconds > 0) {
      final nuevaPosicion = duracion * _arrastreLocal!;
      widget.controller.seekTo(nuevaPosicion);
    }
    setState(() => _arrastreLocal = null);
    widget.onTerminarArrastre();
  }

  @override
  Widget build(BuildContext context) {
    final arrastrando = _arrastreLocal != null;

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, valor, __) {
        final fraccion = _fraccionActual(valor);

        return LayoutBuilder(
          builder: (context, constraints) {
            final anchoTotal = constraints.maxWidth;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (detalles) {
                widget.onIniciarArrastre();
                _actualizarDesdeToque(detalles.localPosition.dx, anchoTotal);
              },
              onTapUp: (_) => _confirmarSeek(),
              onHorizontalDragStart: (detalles) {
                widget.onIniciarArrastre();
                _actualizarDesdeToque(detalles.localPosition.dx, anchoTotal);
              },
              onHorizontalDragUpdate: (detalles) {
                _actualizarDesdeToque(detalles.localPosition.dx, anchoTotal);
              },
              onHorizontalDragEnd: (_) => _confirmarSeek(),
              // Área táctil generosa (padding vertical invisible) para
              // que sea fácil agarrar la barra aunque se vea delgada.
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 14,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      // Fondo + progreso, con la animación de grosor.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        height: arrastrando ? 8 : 4,
                        width: anchoTotal,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: fraccion,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF007AFF),
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Thumb — solo visible mientras se arrastra, y
                      // posicionado según la fracción actual.
                      AnimatedOpacity(
                        opacity: arrastrando ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Align(
                          alignment: Alignment(
                            // Alignment usa -1..1, así que convertimos
                            // la fracción 0..1 a ese rango.
                            (fraccion * 2) - 1,
                            0,
                          ),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}