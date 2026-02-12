package haxe.ui.backend;

import haxe.ui.containers.dialogs.Dialogs.SelectedFileInfo;

using StringTools;

class OpenFileDialogImpl extends OpenFileDialogBase
{
	#if mobile
	public override function show()
	{
		dialogCancelled();
	}
	#elseif js
	private var _fileSelector:haxe.ui.util.html5.FileSelector = new haxe.ui.util.html5.FileSelector();
	
	public override function show()
	{
		var readMode = haxe.ui.util.html5.FileSelector.ReadMode.None;
		if (options.readContents == true)
		{
			if (options.readAsBinary == false) readMode = haxe.ui.util.html5.FileSelector.ReadMode.Text;
			else readMode = haxe.ui.util.html5.FileSelector.ReadMode.Binary;
		}
		
		_fileSelector.selectFile(onFileSelected, readMode, options.multiple, options.extensions);
	}
	
	private function onFileSelected(cancelled:Bool, files:Array<SelectedFileInfo>)
	{
		if (cancelled == false) dialogConfirmed(files);
		else dialogCancelled();
	}
	#else
	private var _fr:openfl.net.FileReferenceList = null;
	private var _refToInfo:Map<openfl.net.FileReference, SelectedFileInfo>;
	private var _infos:Array<SelectedFileInfo>;
	
	public override function show()
	{
		_refToInfo = new Map<openfl.net.FileReference, SelectedFileInfo>();
		_infos = [];
		_fr = new openfl.net.FileReferenceList();
		_fr.addEventListener(openfl.events.Event.SELECT, onSelect, false, 0, true);
		_fr.addEventListener(openfl.events.Event.CANCEL, onCancel, false, 0, true);
		_fr.browse(buildFileFilters());
	}
	
	private function buildFileFilters():Array<openfl.net.FileFilter>
	{
		var f:Array<openfl.net.FileFilter> = null;
		
		if (options.extensions != null && options.extensions.length > 0)
		{
			f = [];
			for (e in options.extensions)
			{
				var ext = e.extension;
				ext = ext.trim();
				if (ext.length == 0) continue;
				
				var parts = ext.split(",");
				var finalParts = [];
				for (p in parts)
				{
					p = p.trim();
					if (p.length == 0) continue;
					finalParts.push("*." + p);
				}
				
				f.push(new openfl.net.FileFilter(e.label, finalParts.join(";")));
			}
		}
		
		return f;
	}
	
	private function onSelect(e:openfl.events.Event)
	{
		var fileList:Array<openfl.net.FileReference> = _fr.fileList;
		destroyFileRef();
		var infos:Array<SelectedFileInfo> = [];
		
		for (fileRef in fileList)
		{
			var fullPath:String = null;
			#if sys
			fullPath = @:privateAccess fileRef.__path;
			#end
			
			var info:SelectedFileInfo = {
				isBinary: false,
				name: fileRef.name,
				fullPath: fullPath
			};
			
			if (options.readContents == true)
			{
				_refToInfo.set(fileRef, info);
			}
			
			infos.push(info);
		}
		
		if (options.readContents == false)
		{
			dialogConfirmed(infos);
		}
		else
		{
			for (fileRef in _refToInfo.keys())
			{
				fileRef.addEventListener(openfl.events.Event.COMPLETE, onFileComplete, false, 0, true);
				fileRef.load();
			}
		}
	}
	
	private function onFileComplete(e:openfl.events.Event)
	{
		var fileRef = cast(e.target, openfl.net.FileReference);
		fileRef.removeEventListener(openfl.events.Event.COMPLETE, onFileComplete);
		var info = _refToInfo.get(fileRef);
		
		if (options.readAsBinary == true)
		{
			info.isBinary = true;
			info.bytes = haxe.io.Bytes.ofData(fileRef.data);
		}
		else
		{
			info.isBinary = false;
			info.text = fileRef.data.toString();
		}
		
		_infos.push(info);
		_refToInfo.remove(fileRef);
		
		if (isMapEmpty())
		{
			var copy = _infos.copy();
			_infos = null;
			_refToInfo = null;
			dialogConfirmed(copy);
		}
	}
	
	private function isMapEmpty()
	{
		if (_refToInfo == null) return true;
		
		var n = 0;
		for (_ in _refToInfo.keys())
		{
			n++;
		}
		
		return (n == 0);
	}
	
	private function onCancel(e:openfl.events.Event)
	{
		destroyFileRef();
		dialogCancelled();
	}
	
	private function destroyFileRef()
	{
		if (_fr == null) return;
		
		_fr.removeEventListener(openfl.events.Event.SELECT, onSelect);
		_fr.removeEventListener(openfl.events.Event.CANCEL, onCancel);
		_fr = null;
	}
	#end
}
