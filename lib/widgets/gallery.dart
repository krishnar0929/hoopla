import 'package:flutter/material.dart';

import '../theme.dart';

/// A network photo with a soft placeholder while loading or if it fails.
class GalleryImage extends StatelessWidget {
  const GalleryImage(this.url, {super.key, this.radius = 12, this.fit = BoxFit.cover});
  final String url;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : Container(color: HC.track, alignment: Alignment.center, child: const Icon(Icons.photo_outlined, color: HC.muted)),
        errorBuilder: (context, _, __) =>
            Container(color: HC.track, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined, color: HC.muted)),
      ),
    );
  }
}

/// Square photo grid. Tapping a photo opens it full screen.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, this.columns = 3});
  final List<String> photos;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: photos.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => openPhotoViewer(context, photos, i),
        child: GalleryImage(photos[i], radius: 10),
      ),
    );
  }
}

void openPhotoViewer(BuildContext context, List<String> photos, int start) {
  Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _PhotoViewer(photos: photos, start: start)));
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.start});
  final List<String> photos;
  final int start;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final controller = PageController(initialPage: widget.start);
  late int index = widget.start;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${index + 1} of ${widget.photos.length}', style: body(15, color: Colors.white)),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: GalleryImage(widget.photos[i], radius: 0, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

const sampleContactNote = 'This is a sample listing to show how Hoopla works. Real providers near you will appear here as they join.';

/// Small "SAMPLE" label on demo listings.
class SampleTag extends StatelessWidget {
  const SampleTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(6)),
      child: Text('SAMPLE', style: body(10, color: HC.muted, weight: FontWeight.w700)),
    );
  }
}
