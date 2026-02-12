package funkin.states.editors;

import haxe.ui.components.Stepper;
import haxe.Json;
import haxe.ui.components.popups.ColorPickerPopup;
import haxe.ui.core.Screen;
import haxe.ui.components.CheckBox;
import haxe.ui.components.Button;
import haxe.ui.components.Slider;
import haxe.ui.backend.flixel.UIState;

import openfl.events.Event;
import openfl.events.KeyboardEvent;

import extensions.openfl.FileReferenceEx;

import flixel.group.FlxContainer;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxBackdrop;

import funkin.states.editors.ui.NoteskinEditorKit.NoteEditorUI;
import funkin.states.editors.ui.DebugBounds;
import funkin.data.*;
import funkin.objects.*;
import funkin.objects.note.*;
import funkin.data.NoteSkinHelper.ColorList;

using funkin.states.editors.ui.ToolKitUtils;

class WIPNoteSkinEditor extends UIState
{
	var isCameraDragging:Bool = false;
	var camHUD:FlxCamera;
	var camBG:FlxCamera;
	
	var bg:FlxSprite;
	var scrollingBG:FlxBackdrop;
	var ghostfields:FlxTypedGroup<PlayField>;
	var playfields:FlxTypedGroup<PlayField>;
	var fieldLayering:FlxContainer;
	var fieldBounds:Array<DebugBounds> = [];
	var uiElements:NoteEditorUI;
	
	var curName:String = 'default';
	var helper:NoteSkinHelper;
	
	var keysArray:Array<Dynamic>;
	var keys:Int = 4;
	
	var receptorAnimArray = [];
	
	var curColorString:String = "Red";
	var curSelectedNote:Dynamic;
	
	public function new(file:String = 'default', ?t_helper:NoteSkinHelper = null)
	{
		super();
		
		if (t_helper == null) setupHandler(file);
		else helper = t_helper;
	}
	
	override function create()
	{
		super.create();
		
		FlxG.cameras.reset();
		FlxG.cameras.add(camHUD = new FlxCamera(), false);
		FlxG.cameras.insert(camBG = new FlxCamera(), 0, false);
		FlxG.camera.bgColor = 0x0;
		camHUD.bgColor = 0x0;
		
		bg = new FlxSprite().loadGraphic(Paths.image('editors/notesbg'));
		bg.setGraphicSize(1280);
		bg.updateHitbox();
		bg.screenCenter();
		bg.alpha = 0.7;
		bg.scrollFactor.set();
		bg.camera = camBG;
		add(bg);
		
		scrollingBG = new FlxBackdrop(Paths.image('editors/arrowloop'));
		scrollingBG.setGraphicSize(1280 * 2);
		scrollingBG.updateHitbox();
		scrollingBG.screenCenter();
		scrollingBG.scrollFactor.set();
		scrollingBG.camera = camBG;
		scrollingBG.alpha = 0.75;
		add(scrollingBG);
		
		fieldLayering = new FlxContainer();
		fieldLayering.camera = FlxG.camera;
		add(fieldLayering);
		
		ghostfields = new FlxTypedGroup<PlayField>();
		fieldLayering.add(ghostfields);
		
		playfields = new FlxTypedGroup<PlayField>();
		fieldLayering.add(playfields);
		
		buildUI();
		buildNotes();
		setUpControls();
		
		FunkinSound.playMusic(Paths.music('offsetSong'), 1, true);
	}
	
	function setUpControls()
	{
		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		// FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
	}
	
	function helperLoading(file:String)
	{
		var noteskin:Null<NoteSkinHelper> = null;
		
		if (FunkinAssets.exists(Paths.noteskin(file)))
		{
			noteskin = new NoteSkinHelper(Paths.noteskin(file));
			curName = file;
		}
		else
		{
			noteskin = new NoteSkinHelper(Paths.noteskin('default'));
			curName = 'default';
		}
		
		return noteskin;
	}
	
	function setupHandler(n:String = 'default')
	{
		helper = helperLoading(n);
		
		NoteSkinHelper.instance = helper;
		NoteSkinHelper.keys = helper.data.noteAnimations.length;
		NoteSkinHelper.arrowSkins = [helper.data.playerSkin, helper.data.opponentSkin];
	}
	
	var resettingColor = false;
	
	function buildUI()
	{
		root.cameras = [camHUD]; // this tells every single component to use this camera
		
		uiElements = new NoteEditorUI();
		uiElements.camera = camHUD;
		add(uiElements);
		
		refreshUIValues();
		uiElements.toolBar.showBounds.value = false;
		
		refreshSkinDropdown();
		uiElements.toolBar.skinDropdown.onChange = (ui) -> {
			if (ui.data.isDropDownItem())
			{
				setupHandler(ui.data.id);
				uiElements.toolBar.skinName.value = ui.data.id;
				
				refreshUIValues();
				buildNotes(true);
				
				FlxG.sound.play(Paths.sound('ui/success'));
				ToolKitUtils.makeNotification('Skin Change', 'Successfullyu changed skin to ${ui.data.id}', Success);
			}
		}
		
		uiElements.toolBar.saveButton.onClick = (ui) -> {
			saveSkinToFile();
		}
		
		uiElements.toolBar.refreshButton.onClick = (ui) -> {
			setupHandler(curName);
			buildNotes(false);
			refreshUIValues();
			
			FlxG.sound.play(Paths.sound('ui/openPopup'));
			ToolKitUtils.makeNotification('Refreshed Skin', 'Refreshed current noteskin. Any changes may have been lost.', Info);
		}
		
		uiElements.toolBar.bgView.findComponent('bgColour', ColorPickerPopup).onChange = (ui) -> {
			final newColour = FlxColor.fromString(ui.value.toString());
			if (camBG.bgColor != newColour)
			{
				uiElements.toolBar.findComponent('coolBGCheckbox', CheckBox).value = false;
				uiElements.toolBar.gridBGCheckbox.value = false;
			}
			camBG.bgColor = newColour;
		}
		
		uiElements.toolBar.coolBGCheckbox.onChange = (ui) -> {
			bg.visible = ui.value.toBool();
			scrollingBG.visible = ui.value.toBool();
			if (bg.visible) camBG.bgColor = FlxColor.BLACK;
		}
		
		uiElements.toolBar.showBounds.onChange = (ui) -> {
			final show = ui.value.toBool();
			if (fieldBounds.length > 0 && fieldBounds != null)
			{
				for (i in fieldBounds)
				{
					if (i != null) i.visible = show;
				}
			}
		}
		
		uiElements.toolBar.enableGhost.onClick = (ui) -> {
			spawnGhostField();
		}
		
		uiElements.toolBar.ghostInFront.onChange = (ui) -> {
			ghostfields.zIndex = ui.value.toBool() ? 999 : -1;
			fieldLayering.sort(SortUtil.sortByZ, flixel.util.FlxSort.ASCENDING);
		}
		
		var slider = uiElements.toolBar.ghostSettings.findComponent('ghostAlphaSlider', Slider);
		if (slider != null)
		{
			slider.onChange = (ui) -> {
				for (i in ghostfields.members)
				{
					final a = ui.value.toFloat();
					
					for (j in i.members)
						j.targetAlpha = a;
				}
			}
		}
		
		uiElements.settingsBox.animationsDropdown.onChange = (ui) -> {
			refreshAnimDropdown('receptors');
		}
		
		uiElements.settingsBox.reloadTextures.onClick = (ui) -> {
			helper.data.playerSkin = uiElements.settingsBox.playerTexture.value;
			helper.data.opponentSkin = uiElements.settingsBox.opponentTexture.value;
			helper.data.extraSkin = uiElements.settingsBox.extraTexture.value;
			
			NoteSkinHelper.arrowSkins = [helper.data.playerSkin, helper.data.opponentSkin];
			buildNotes(true);
			
			FlxG.sound.play(Paths.sound('ui/success'));
			ToolKitUtils.makeNotification('Reloaded Textures', 'Reloaded textures successfully', Success);
		}
		
		uiElements.settingsBox.scalecount.onChange = (ui) -> {
			final newScale = ui.value.toFloat();
			
			for (i in playfields.members)
			{
				for (j in i.members)
				{
					j.scale.set(newScale, newScale);
					j.updateHitbox();
				}
			}
			helper.data.scale = newScale;
		}
		
		uiElements.settingsBox.lanecount.onChange = (ui) -> {
			// SIGH
			buildNotes(true);
		}
		
		uiElements.settingsBox.keycount.onChange = (ui) -> {
			final newKeyCount = ui.value.toInt();
			
			if (newKeyCount > helper.data.noteAnimations.length && newKeyCount > helper.data.receptorAnimations.length)
			{
				if (newKeyCount >= 10)
				{
					ToolKitUtils.makeNotification('Key Warning', 'Above 10 keys is not recommended due to performance.', Warning);
					FlxG.sound.play(Paths.sound('ui/warn'));
				}
				else
				{
					ToolKitUtils.makeNotification('Key Addition', 'Key $newKeyCount was created (based on values from Key 1)', Success);
					FlxG.sound.play(Paths.sound('ui/success'));
				}
				
				helper.data.noteAnimations.push(helper.data.noteAnimations[0]);
				helper.data.receptorAnimations.push(helper.data.receptorAnimations[0]);
			}
			
			if (newKeyCount < helper.data.noteAnimations.length && newKeyCount < helper.data.receptorAnimations.length)
			{
				if (newKeyCount <= 1)
				{
					ToolKitUtils.makeNotification('Key Error', 'You can\'t have zero keys..', Warning);
					FlxG.sound.play(Paths.sound('ui/warn'));
				}
				else
				{
					ToolKitUtils.makeNotification('Key Removal', 'Key ${newKeyCount + 1} was removed', Success);
					FlxG.sound.play(Paths.sound('ui/success'));
				}
				
				helper.data.noteAnimations.pop();
				helper.data.receptorAnimations.pop();
			}
			
			keys = newKeyCount;
			
			buildNotes(true);
		}
		
		uiElements.settingsBox.shaderColoringBox.onClick = (ui) -> {
			helper.data.inGameColoring = ui.value.toBool();
			buildNotes(true);
			trace(ui.value.toBool());
		}
		
		uiElements.settingsBox.splashBox.onChange = (ui) -> {
			// do more shit here abt not going to splashes mode if theyre disabled. or smth. idk
			
			helper.data.splashesEnabled = ui.value.toBool();
		}
		
		uiElements.settingsBox.antialiasingBox.onChange = (ui) -> {
			helper.data.antialiasing = ui.value.toBool();
			for (i in playfields.members)
			{
				for (j in i.members)
					j.antialiasing = helper.data.antialiasing;
			}
		}
		
		uiElements.settingsBox.pixSus.onChange = (ui) -> {
			helper.data.sustainSuffix = ui.value;
		}
		
		uiElements.settingsBox.widthDiv.onChange = (ui) -> {
			helper.data.pixelSize[0] = ui.value.toInt();
		}
		uiElements.settingsBox.heightDiv.onChange = (ui) -> {
			helper.data.pixelSize[1] = ui.value.toInt();
		}
		
		uiElements.settingsBox.noteColorPicker.onChange = (ui) -> {
			final colour = FlxColor.fromString(ui.value.toString());
			var id = curSelectedNote.noteData;
			
			switch (curColorString)
			{
				case 'Red':
					helper.data.arrowRGBdefault[id].r = colour;
				case 'Green':
					helper.data.arrowRGBdefault[id].g = colour;
				case 'Blue':
					helper.data.arrowRGBdefault[id].b = colour;
			}
			updateStrumColors();
		}
		
		uiElements.settingsBox.resetDefColors.onClick = (ui) -> {
			resetColorValues('Default');
		};
		uiElements.settingsBox.resetJsonColors.onClick = (ui) -> {
			resetColorValues('File');
		};
	}
	
	function refreshUIValues()
	{
		uiElements.settingsBox.splashTexture.value = helper.data.noteSplashSkin;
		uiElements.settingsBox.playerTexture.value = helper.data.playerSkin;
		uiElements.settingsBox.opponentTexture.value = helper.data.opponentSkin;
		uiElements.settingsBox.extraTexture.value = helper.data.extraSkin;
		
		uiElements.settingsBox.scalecount.value = helper.data.scale;
		uiElements.settingsBox.keycount.value = helper.data.noteAnimations.length;
		uiElements.settingsBox.lanecount.value = 1;
		
		uiElements.settingsBox.splashBox.value = helper.data.splashesEnabled;
		uiElements.settingsBox.antialiasingBox.value = helper.data.antialiasing;
		
		uiElements.settingsBox.pixSus.value = helper.data.sustainSuffix;
		uiElements.settingsBox.isPixel.value = helper.data.isPixel;
		uiElements.settingsBox.widthDiv.value = helper.data.pixelSize[0];
		uiElements.settingsBox.heightDiv.value = helper.data.pixelSize[1];
		
		uiElements.toolBar.coolBGCheckbox.value = true;
		
		uiElements.settingsBox.shaderColoringBox.value = helper.data.inGameColoring;
		
		uiElements.settingsBox.noteColorPicker.value = helper.data.arrowRGBdefault[0].r;
		uiElements.settingsBox.curColorDropdown.value = "Red";
	}
	
	function resetColorValues(type:String = 'Default')
	{
		trace(type);
		
		switch (type)
		{
			case 'File':
				var json = helperLoading(curName);
				trace(json.data.arrowRGBdefault.copy());
				
				helper.data.arrowRGBquant = json.data.arrowRGBquant.copy();
				helper.data.arrowRGBdefault = json.data.arrowRGBdefault.copy();
			default:
				var defaultColors:Array<ColorList> = [
					{r: 0xFFC24B99, g: 0xFFFFFFFF, b: 0xFF3C1F56},
					{r: 0xFF00FFFF, g: 0xFFFFFFFF, b: 0xFF1542B7},
					{r: 0xFF12FA05, g: 0xFFFFFFFF, b: 0xFF0A4447},
					{r: 0xFFF9393F, g: 0xFFFFFFFF, b: 0xFF651038}
				];
				var quantDefaultColors:Array<ColorList> = [
					{r: 0xFFE51919, g: 0xFFFFFF, b: 0xFF5B0A30}, // 4th
					{r: 0xFF193BE5, g: 0xFFFFFF, b: 0xFF0A3B5B}, // 8th
					{r: 0xFFA119E5, g: 0xFFFFFF, b: 0xFF1D0A5B}, // 12th
					{r: 0xFF26D93E, g: 0xFFFFFF, b: 0xFF24560F}, // 16th
					{r: 0xFF0000B2, g: 0xFFFFFF, b: 0xFF002247}, // 20th
					{r: 0xFFA119E5, g: 0xFFFFFF, b: 0xFF1D0A5B}, // 24th
					{r: 0xFFE5C319, g: 0xFFFFFF, b: 0xFF5B2A0A}, // 32nd
					{r: 0xFFA119E5, g: 0xFFFFFF, b: 0xFF1D0A5B}, // 48th
					{r: 0xFF13ECA4, g: 0xFFFFFF, b: 0xFF085D18}, // 64th
					{r: 0xFF3A3A6C, g: 0xFFFFFF, b: 0xFF17202B}, // 96th
					{r: 0xFF3A3A6C, g: 0xFFFFFF, b: 0xFF17202B} // 192nd
				];
				trace(defaultColors.copy());
				
				helper.data.arrowRGBquant = quantDefaultColors.copy();
				helper.data.arrowRGBdefault = defaultColors.copy();
		}
		refreshUIValues();
		updateStrumColors();
	}
	
	function updateStrumColors()
	{
		if (!helper.data.inGameColoring) return;
		
		for (field in playfields.members)
		{
			for (strumnote in field.members)
			{
				if (strumnote.animation.curAnim.name != 'static') strumnote.rgbShader.setColors(NoteSkinHelper.colorToArray(helper.data.arrowRGBdefault[strumnote.noteData]));
			}
		}
	}
	
	function spawnGhostField()
	{
		if (ghostfields.members.length > 0)
		{
			for (i in ghostfields.members)
				i = FlxDestroyUtil.destroy(i);
				
			ghostfields.clear();
		}
		
		for (i in playfields.members)
		{
			var field = new PlayField(i.baseX, i.baseY, i.keyCount, null, true, false, true, i.player);
			field.baseAlpha = uiElements.toolBar.ghostAlphaSlider.value;
			field.generateReceptors();
			field.fadeIn(true);
			field.quants = false;
			ghostfields.add(field);
			
			for (j in field.members)
			{
				final ogNote = i.members[j.noteData];
				
				j.scrollFactor.set(1, 1);
				j.antialiasing = ogNote.antialiasing;
				j.useRGBShader = ogNote.useRGBShader;
				j.playAnim(ogNote.getAnimName(), true);
			}
		}
	}
	
	function buildNotes(?skipTween:Bool = false)
	{
		// re-setting it in case it breaks
		NoteSkinHelper.instance = helper;
		trace('rebuilding notes');
		
		ClientPrefs.quants = false;
		
		if (playfields.members.length > 0) playfields.clear();
		if (fieldBounds.length > 0)
		{
			for (i in fieldBounds)
			{
				remove(i);
				i = FlxDestroyUtil.destroy(i);
			}
			fieldBounds = [];
		}
		
		for (i in 0...Std.int(uiElements.settingsBox.lanecount.value))
		{
			var field = new PlayField(112 * 3, 112 * 2, uiElements.settingsBox.keycount.value, null, true, false, true, i);
			field.baseAlpha = 0.8;
			field.generateReceptors();
			field.fadeIn(skipTween);
			field.quants = false;
			playfields.add(field);
			
			// annoying but whatever
			for (i in field.members)
			{
				i.scrollFactor.set(1, 1);
				i.antialiasing = helper.data.antialiasing;
				i.useRGBShader = helper.data.inGameColoring;
				i.playAnim('static', true);
				
				var bounds = new DebugBounds(i);
				bounds.visible = uiElements.toolBar.showBounds.value;
				add(bounds);
				fieldBounds.push(bounds);
			}
		}
		
		curSelectedNote = playfields.members[0].members[0];
	}
	
	function refreshAnimDropdown(current:String = 'receptors')
	{
		switch (current)
		{
			case 'receptors':
				final receptorAnimArray = [];
				final data = curSelectedNote != null ? curSelectedNote.noteData ?? 0 : 0;
				
				for (anim in helper.data.receptorAnimations[data])
				{
					receptorAnimArray.push(ToolKitUtils.makeSimpleDropDownItem(anim.anim));
				}
				uiElements.settingsBox.animationsDropdown.populateList(receptorAnimArray);
				
				uiElements.settingsBox.playerTexture.value = helper.data.playerSkin;
				uiElements.settingsBox.opponentTexture.value = helper.data.opponentSkin;
				uiElements.settingsBox.extraTexture.value = helper.data.extraSkin;
				
			default:
				// lol
		}
	}
	
	function refreshSkinDropdown()
	{
		var skinList = [];
		#if MODS_ALLOWED
		var files = Paths.listAllFilesInDirectory('data/noteskins/');
		
		for (i in Paths.listAllFilesInDirectory('noteskins/'))
			files.push(i);
			
		for (file in files)
		{
			if (file.endsWith('.json'))
			{
				var skinToCheck:String = file.withoutDirectory().withoutExtension();
				
				if (!skinList.contains(skinToCheck)) skinList.push(skinToCheck);
			}
		}
		#end
		
		uiElements.toolBar.skinDropdown.populateList([for (i in skinList) ToolKitUtils.makeSimpleDropDownItem(i)]);
		uiElements.toolBar.skinDropdown.dataSource.sort(null, ASCENDING);
	}
	
	override function update(elapsed)
	{
		super.update(elapsed);
		
		if (scrollingBG != null) scrollingBG.x += 0.25 * (elapsed * 240);
		FlxG.mouse.visible = true;
		
		controlCamera(elapsed);
		
		// only reason these r separate funcs is just for better readability & workflow
		// i dont want the giant block of code at the top of my func im sorry
		handleReceptorAlpha(elapsed);
		handleReceptorUpdate(elapsed);
		
		if ((ToolKitUtils.isHaxeUIHovered(camHUD) && FlxG.mouse.justPressed) || FlxG.mouse.justPressedRight)
		{
			FlxG.sound.play(Paths.sound('ui/mouseClick'));
		}
	}
	
	function handleReceptorUpdate(elapsed:Float)
	{
		if (curSelectedNote != null)
		{
			final animName = curSelectedNote.getAnimName();
			final baseOffset = getOffsetFromAnim('receptor', animName, curSelectedNote.noteData);
			final bounds = fieldBounds[curSelectedNote.noteData];
			
			// moving offsets with ur mouse
			if (FlxG.mouse.overlaps(bounds.middle) && FlxG.mouse.pressedRight)
			{
				final newOffset = [baseOffset[0] - FlxG.mouse.deltaViewX, baseOffset[1] - FlxG.mouse.deltaViewY];
				addReceptorOffset(curSelectedNote, animName, newOffset);
			}
			
			// reset current offset to 0,0
			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.R)
			{
				addReceptorOffset(curSelectedNote, animName, [0, 0]);
				ToolKitUtils.makeNotification('Offsetting', 'Current animation offset reset to [0, 0].', Info);
				FlxG.sound.play(Paths.sound('ui/openPopup'));
			}
		}
	}
	
	function handleReceptorAlpha(elapsed:Float)
	{
		if (playfields != null && playfields.members.length > 0)
		{
			for (field in playfields)
			{
				for (i in 0...keys)
				{
					final note = field.members[i];
					final bounds = fieldBounds[i];
					
					if (FlxG.mouse.overlaps(bounds.middle) && note != curSelectedNote)
					{
						note.alpha = 0.9;
						if (FlxG.mouse.justPressed)
						{
							curSelectedNote = note;
							refreshAnimDropdown('receptors');
						}
					}
					else note.alpha = (note == curSelectedNote) ? 1 : 0.6;
				}
			}
		}
	}
	
	function controlCamera(elapsed:Float)
	{
		// flagging ctrl so that if u reset a offset it doesnt also reset the camera
		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL)
		{
			FlxG.camera.zoom = 1;
			FlxG.camera.scroll.x = 0;
			FlxG.camera.scroll.y = 0;
		}
		
		if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3)
		{
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom;
		}
		if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1)
		{
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom;
		}
		
		if (FlxG.mouse.justReleasedMiddle) isCameraDragging = false;
		
		if (ToolKitUtils.isHaxeUIHovered(camHUD) && !isCameraDragging) return;
		
		if (FlxG.mouse.justPressedMiddle)
		{
			isCameraDragging = true;
			FlxG.sound.play(Paths.sound('ui/mouseMiddleClick'));
		}
		
		if (FlxG.mouse.pressedMiddle && FlxG.mouse.justMoved)
		{
			var mult = FlxG.keys.pressed.SHIFT ? 2 : 1;
			FlxG.camera.scroll.x -= FlxG.mouse.deltaViewX * mult;
			FlxG.camera.scroll.y -= FlxG.mouse.deltaViewY * mult;
		}
		
		if (FlxG.mouse.wheel != 0)
		{
			FlxG.camera.zoom += FlxG.mouse.wheel * (0.1 * FlxG.camera.zoom);
		}
		
		FlxG.camera.zoom = FlxMath.bound(FlxG.camera.zoom, 0.1, 6);
	}
	
	var _fileReference:Null<FileReferenceEx> = null;
	
	function saveSkinToFile()
	{
		if (_fileReference != null) return;
		
		var json =
			{
				"globalSkin": helper.data.globalSkin,
				"playerSkin": helper.data.playerSkin,
				"opponentSkin": helper.data.opponentSkin,
				"extraSkin": helper.data.extraSkin,
				"noteSplashSkin": helper.data.noteSplashSkin,
				
				"isPixel": uiElements.settingsBox.isPixel.value,
				"pixelSize": helper.data.pixelSize,
				"antialiasing": uiElements.settingsBox.antialiasingBox.value,
				"sustainSuffix": helper.data.sustainSuffix,
				
				"noteAnimations": helper.data.noteAnimations,
				
				"receptorAnimations": helper.data.receptorAnimations,
				
				"noteSplashAnimations": helper.data.noteSplashAnimations,
				
				"singAnimations": helper.data.singAnimations,
				"scale": helper.data.scale,
				"splashesEnabled": helper.data.splashesEnabled,
				
				"inGameColoring": helper.data.inGameColoring,
				"arrowRGBdefault": helper.data.arrowRGBdefault,
				"arrowRGBquant": helper.data.arrowRGBquant
			}
			
		final dataToSave:String = Json.stringify(json, "\t");
		
		if (dataToSave.length > 0)
		{
			_fileReference = new FileReferenceEx(); // maybe do smth about this idk
			
			_fileReference.addEventListener(Event.SELECT, onFileSaveComplete);
			_fileReference.addEventListener(Event.CANCEL, onFileSaveCancel);
			_fileReference.save(dataToSave, '${uiElements.toolBar.skinName.value}.json');
		}
	}
	
	function cleanUpFileReference()
	{
		if (_fileReference == null) return;
		
		_fileReference.removeEventListener(Event.SELECT, onFileSaveComplete);
		_fileReference.removeEventListener(Event.CANCEL, onFileSaveCancel);
		
		_fileReference = null;
	}
	
	function onFileSaveComplete(_)
	{
		if (_fileReference == null) return;
		
		cleanUpFileReference();
		
		ToolKitUtils.makeNotification('Skin File Saving', 'Skin was successfully saved.', Success);
		FlxG.sound.play(Paths.sound('ui/success'));
	}
	
	function onFileSaveCancel(_)
	{
		if (_fileReference == null) return;
		
		cleanUpFileReference();
		
		ToolKitUtils.makeNotification('Skin File Saving', 'Skin saving was canceled.', Warning);
		FlxG.sound.play(Paths.sound('ui/warn'));
	}
	
	function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		// if (cpuControlled || paused || !startedCountdown) return;
		
		if (key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			// this keeps crashing idk why
			try
			{
				if (playfields != null && playfields.members.length > 0)
				{
					for (field in playfields.members)
					{
						if (field.inControl && !field.autoPlayed && field.playerControls && !FlxG.keys.pressed.CONTROL)
						{
							var spr:StrumNote = field.members[key];
							shuffleThroughAnims(spr);
						}
					}
				}
			}
			catch (e) {}
		}
	}
	
	function shuffleThroughAnims(key:StrumNote)
	{
		if (key != null)
		{
			switch (key.animation.curAnim.name)
			{
				case 'static':
					strumPlayAnim('pressed', key, 0);
				case 'pressed':
					strumPlayAnim('confirm', key, 0);
				case 'confirm':
					strumPlayAnim('static', key, 0);
			}
		}
	}
	
	function strumPlayAnim(anim:String, spr:StrumNote, time:Float = 1)
	{
		if (spr != null)
		{
			spr.playAnim(anim, true, null);
			spr.resetAnim = time;
		}
	}
	
	function addReceptorOffset(note:Dynamic, name:String = 'static', offsets:Array<Float>)
	{
		if (offsets == null || offsets.length < 2) offsets = [0, 0];
		
		if (note != null)
		{
			note.addOffset(name, offsets[0], offsets[1]);
			helper.data.receptorAnimations[note.noteData][getAnimIndex(name)].offsets = offsets;
			
			note.playAnim(name, true, null);
		}
	}
	
	function getAnimIndex(anim:String):Int
	{
		return switch (anim)
		{
			case 'pressed': 1;
			case 'confirm': 2;
			default: 0;
		}
	}
	
	// quick handler to get offsets quickly from an animation
	function getOffsetFromAnim(type:String = 'receptors', anim:String = 'static', data:Int)
	{
		var offset:Null<Array<Float>> = switch (type)
		{
			default:
				[0, 0];
			case 'receptor':
				final animIndex = getAnimIndex(anim);
				
				helper.data.receptorAnimations[data][animIndex].offsets;
		}
		final _x = offset[0] ?? 0;
		final _y = offset[1] ?? 0;
		
		return [_x, _y];
	}
	
	function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
					if (key == keysArray[i][j]) return i;
			}
		}
		return -1;
	}
}
