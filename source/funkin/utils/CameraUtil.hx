package funkin.utils;

import flixel.system.FlxAssets.FlxShader;

import openfl.filters.ShaderFilter;

@:access(flixel.FlxCamera)
@:access(flixel.system.frontEnds.CameraFrontEnd)
@:nullSafety
class CameraUtil
{
	/**
		returns the last camera in FlxG.cameras.list
		equivalent to `FlxG.cameras.list[FlxG.cameras.list.length - 1]`
	**/
	public static var lastCamera(get, never):FlxCamera;
	
	static function get_lastCamera():FlxCamera return FlxG.cameras.list[FlxG.cameras.list.length - 1];
	
	/**
		convenient function to making a camera and adding it to the stack as well
		* @param	add	whether it should be automatically added to the stack
		* @return	The new Camera
	**/
	public static inline function quickCreateCam(add:Bool = true):FlxCamera
	{
		var cam = new FlxCamera();
		cam.bgColor = 0x0;
		
		if (add) FlxG.cameras.add(cam, false);
		
		return cam;
	}
	
	public static function insertFlxCamera(idx:Int, camera:FlxCamera, defDraw:Bool = false)
	{
		var cameras = [
			for (i in FlxG.cameras.list)
				{
					cam: i,
					defaultDraw: FlxG.cameras.defaults.contains(i)
				}
		];

		for (i in cameras)
			FlxG.cameras.remove(i.cam, false);

		cameras.insert(idx, {cam: camera, defaultDraw: defDraw});

		for (i in cameras)
			FlxG.cameras.add(i.cam, i.defaultDraw);
	}
}
