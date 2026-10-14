// Run from Illustrator: File > Scripts > Other Script... (Ctrl+F12)
//
// Exports the "gameover" artboard of the active document (radar.svg) piece
// by piece, whichever artboard is active.  The document is
// left alone: each top-level item that touches the active artboard is
// duplicated into a scratch 1920x1080 document, exported as a transparent PNG
// clipped to the artboard (art/item_NN.png) and the scratch document is
// closed without saving.  art/items.json lists every exported item with its
// type, name and bounds (artboard pixels, y down); art/composite.png is the
// whole artboard.  tools/gameover/build_gameover_art.py crops and names
// the pieces for the theme.
#target illustrator
(function () {
	var here = File($.fileName).parent;
	var out = Folder(here + "/art/card");
	if (!out.exists) out.create();
	var source = app.activeDocument;
	var abIndex = -1;
	for (var a = 0; a < source.artboards.length; a++) {
		if (String(source.artboards[a].name).toLowerCase() == "gameover") abIndex = a;
	}
	if (abIndex < 0) { alert("No artboard named gameover in " + source.name); return; }
	source.artboards.setActiveArtboardIndex(abIndex);
	var abRect = source.artboards[abIndex].artboardRect; // left, top, right, bottom
	var abW = abRect[2] - abRect[0], abH = abRect[1] - abRect[3];

	function q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"'; }
	function num(n) { return Math.round(n * 100) / 100; }

	function touchesArtboard(it) {
		var b = it.visibleBounds;
		return !(b[2] < abRect[0] || b[0] > abRect[2] || b[1] < abRect[3] || b[3] > abRect[1]);
	}

	function scratch() {
		var doc = app.documents.add(DocumentColorSpace.RGB, abW, abH);
		doc.artboards[0].artboardRect = abRect;
		return doc;
	}

	function exportPng(doc, name) {
		var opts = new ExportOptionsPNG24();
		opts.transparency = true;
		opts.antiAliasing = true;
		opts.artBoardClipping = true;
		opts.horizontalScale = 100;
		opts.verticalScale = 100;
		doc.exportFile(new File(out + "/" + name), ExportType.PNG24, opts);
	}

	// The P1 card: the fully opaque top-level group whose left edge is
	// nearest the artboard's; its pieces (groups opened down to their
	// leaves, clipping groups kept whole), back to front.
	var card = null;
	for (var L = source.layers.length - 1; L >= 0; L--) {
		var layer = source.layers[L];
		if (!layer.visible) continue;
		for (var i = layer.pageItems.length - 1; i >= 0; i--) {
			var it = layer.pageItems[i];
			if (it.parent != layer || it.hidden || it.typename != "GroupItem") continue;
			if (!touchesArtboard(it) || it.opacity < 99) continue;
			var b = it.visibleBounds;
			if (b[1] > abRect[1] - 540 && (!card || b[0] < card.visibleBounds[0])) card = it;
		}
	}
	if (!card) { alert("No P1 card group found"); return; }
	var items = [];
	function walk(g) {
		for (var k = g.pageItems.length - 1; k >= 0; k--) {
			var c = g.pageItems[k];
			if (c.parent != g || c.hidden) continue;
			if (c.typename == "GroupItem" && !c.clipped) walk(c); else items.push(c);
		}
	}
	walk(card);

	var rows = [];
	for (var n = 0; n < items.length; n++) {
		var it = items[n];
		var id = (n < 10 ? "0" : "") + n;
		var doc = scratch();
		it.duplicate(doc.layers[0], ElementPlacement.PLACEATBEGINNING);
		exportPng(doc, "item_" + id + ".png");
		doc.close(SaveOptions.DONOTSAVECHANGES);
		var b = it.visibleBounds;
		var text = "";
		if (it.typename == "TextFrame") { try { text = it.contents; } catch (e) {} }
		rows.push("{" + q("id") + ":" + q(id) + "," + q("type") + ":" + q(it.typename) + "," + q("name") + ":" + q(it.name || "") +
			"," + q("text") + ":" + q(text) + "," + q("opacity") + ":" + num(it.opacity) +
			"," + q("bounds") + ":[" + num(b[0] - abRect[0]) + "," + num(abRect[1] - b[1]) + "," + num(b[2] - abRect[0]) + "," + num(abRect[1] - b[3]) + "]}");
	}

	var all = scratch();
	for (var c = 0; c < items.length; c++) items[c].duplicate(all.layers[0], ElementPlacement.PLACEATBEGINNING);
	exportPng(all, "composite.png");
	all.close(SaveOptions.DONOTSAVECHANGES);

	var f = new File(out + "/items.json");
	f.encoding = "UTF-8";
	f.open("w");
	f.write("[\n" + rows.join(",\n") + "\n]\n");
	f.close();
	alert("Game over card: " + items.length + " items exported to " + out.fsName);
})();
