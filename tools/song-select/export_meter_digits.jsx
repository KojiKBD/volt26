// Run from Illustrator: File > Scripts > Other Script... (Ctrl+F12)
//
// Renders the meter badge digits of the song select (the "12" of the mockup)
// as two strips of ten 160x200 cells, 0 to 9 from the left:
//   art/digits_boxed.png  a black digit (Source Serif Black) in a white box
//                         with a black border and a black drop shadow;
//   art/digits_plain.png  a white digit (Futura Bold) with a black outline and
//                         a black drop shadow.
// tools/song-select/build_song_select_art.py splits each strip into the
// white and the black ink layers the theme recolours.
#target illustrator
(function () {
	var here = File($.fileName).parent;
	var CELL_W = 160, CELL_H = 200;
	function rgb(r, g, b) { var c = new RGBColor(); c.red = r; c.green = g; c.blue = b; return c; }
	var BLACK = rgb(0, 0, 0), WHITE = rgb(255, 255, 255);

	function paint(item, fill, strokeWidth) {
		if (item.typename == "GroupItem") {
			for (var i = 0; i < item.pageItems.length; i++) paint(item.pageItems[i], fill, strokeWidth);
		} else if (item.typename == "CompoundPathItem") {
			for (var j = 0; j < item.pathItems.length; j++) paint(item.pathItems[j], fill, strokeWidth);
		} else if (item.typename == "PathItem") {
			item.filled = true;
			item.fillColor = fill;
			item.stroked = strokeWidth > 0;
			if (strokeWidth > 0) {
				item.strokeColor = BLACK;
				item.strokeWidth = strokeWidth;
				item.strokeJoin = StrokeJoin.ROUNDENDJOIN;
				item.strokeCap = StrokeCap.ROUNDENDCAP;
			}
		}
	}

	function centre(item, cx, cy) {
		var b = item.geometricBounds; // left, top, right, bottom (y up)
		item.translate(cx - (b[0] + b[2]) / 2, cy - (b[1] + b[3]) / 2);
	}

	function glyph(doc, digit, fontName, size) {
		var t = doc.textFrames.add();
		t.contents = String(digit);
		t.textRange.characterAttributes.textFont = app.textFonts.getByName(fontName);
		t.textRange.characterAttributes.size = size;
		return t.createOutline();
	}

	function strip(name, build) {
		var doc = app.documents.add(DocumentColorSpace.RGB, CELL_W * 10, CELL_H);
		var ab = doc.artboards[0].artboardRect; // left, top, right, bottom
		for (var d = 0; d < 10; d++) {
			var cx = ab[0] + CELL_W * d + CELL_W / 2;
			var cy = ab[1] - CELL_H / 2;
			build(doc, d, cx, cy);
		}
		var opts = new ExportOptionsPNG24();
		opts.transparency = true; opts.antiAliasing = true; opts.artBoardClipping = true;
		opts.horizontalScale = 100; opts.verticalScale = 100;
		doc.exportFile(new File(here + "/art/" + name), ExportType.PNG24, opts);
		doc.close(SaveOptions.DONOTSAVECHANGES);
	}

	// Box 92 x 112 with an 8 px border, its shadow 7 right and 14 down.
	strip("digits_boxed.png", function (doc, d, cx, cy) {
		var w = 92, h = 112, sx = 7, sy = -14;
		var shadow = doc.pathItems.rectangle(cy + h / 2 + sy, cx - w / 2 + sx, w, h);
		paint(shadow, BLACK, 8);
		var box = doc.pathItems.rectangle(cy + h / 2, cx - w / 2, w, h);
		paint(box, WHITE, 8);
		var g = glyph(doc, d, "SourceSerifRoman-Black", 104);
		paint(g, BLACK, 0);
		centre(g, cx, cy);
	});

	// White digit, 16 px black outline, shadow 7 right and 14 down.
	strip("digits_plain.png", function (doc, d, cx, cy) {
		var shadow = glyph(doc, d, "Futura-Bold", 118);
		paint(shadow, BLACK, 16);
		centre(shadow, cx + 7, cy - 14);
		var outline = glyph(doc, d, "Futura-Bold", 118);
		paint(outline, BLACK, 16);
		centre(outline, cx, cy);
		var face = glyph(doc, d, "Futura-Bold", 118);
		paint(face, WHITE, 0);
		centre(face, cx, cy);
	});
})();
