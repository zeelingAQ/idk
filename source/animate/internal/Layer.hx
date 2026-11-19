package animate.internal;

import animate.FlxAnimateJson.LayerJson;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

class Layer implements IFlxDestroyable
{
	public var timeline:Null<Timeline>;
	public var frames:Null<Array<Frame>>;
	public var frameCount(get, never):Int;
	public var visible:Bool;
	public var name:String;
	public var layerType:LayerType;
	public var parentLayer:Null<Layer>;

	var frameIndices:Null<Array<Int>>;

	public function new(?timeline:Timeline)
	{
		this.frames = [];
		this.frameIndices = [];
		this.visible = true;
		this.timeline = timeline;
		this.name = "";
		this.layerType = NORMAL;
	}

	public function getFrameAtIndex(index:Int):Null<Frame>
	{
		index = FlxMath.maxInt(index, 0);
		if (index > (frameCount - 1)) return null;
		var frameIndex = frameIndices[index];
		return frames[frameIndex];
	}

	public function getBounds(frameIndex:Int, ?rect:FlxRect, ?matrix:FlxMatrix, ?includeFilters:Bool = true, ?useCachedBounds:Bool = false):FlxRect
	{
		rect ??= FlxRect.get();
		var frame = getFrameAtIndex(frameIndex);
		if (frame != null) return frame.getBounds((frameIndex - frame.index), rect, matrix, includeFilters, useCachedBounds);
		Timeline.applyMatrixToRect(rect, matrix);
		return rect;
	}

	@:allow(animate.internal.Timeline)
	function _loadJson(layer:LayerJson, parent:FlxAnimateFrames, ?layerIndex:Int, ?layers:Array<Layer>):Void
	{
		this.name = layer.LN;
		var clippedBy:Null<String> = layer.Clpb;
		var isMasked:Bool = clippedBy != null;

		if (isMasked && layerIndex != null && layers != null)
		{
			var i = layerIndex - 1;
			var foundLayer:Bool = false;
			this.layerType = CLIPPED;

			while (i >= 0)
			{
				var aboveLayer = layers[i--];
				if (aboveLayer != null && aboveLayer.name == clippedBy && aboveLayer.layerType == CLIPPER)
				{
					parentLayer = aboveLayer;
					foundLayer = true;
					break;
				}
			}

			if (!foundLayer)
			{
				parentLayer = null;
				isMasked = false;
				visible = false;
			}
		}
		else
		{
			final type:Null<String> = layer.LT;
			this.layerType = type != null ? switch (type)
			{
				case "Clp" | "Clipper": CLIPPER;
				case "Fld" | "Folder": FOLDER;
				default: NORMAL;
			} : NORMAL;
		}

		if (this.layerType == CLIPPER) visible = false;

		if (this.layerType != FOLDER)
		{
			for (i => frameJson in layer.FR)
			{
				var frame = new Frame(this);
				frame._loadJson(frameJson, parent);
				
				// 【重写点】完全无视原来的 frame.I（比如377）。
				// 这里的索引完全由当前数组真实下标 `i` 决定，永远从 0 开始！
				frame.index = i; 
				
				frames.push(frame);

				for (_ in 0...frame.duration)
					frameIndices.push(i);
			}
		}

		if (!isMasked) return;

		for (frame in frames)
		{
			if (frame.elements.length <= 0) continue;
			frame._dirty = true;
			frame._requireBake = true;
		}
	}

	public function destroy():Void
	{
		parentLayer = null;
		if (frames != null)
		{
			for (frame in frames) frame.destroy();
		}
		frames = null;
		frameIndices = null;
	}

	inline function get_frameCount():Int return frameIndices.length;
}

enum abstract LayerType(Int) to Int
{
	var NORMAL;
	var CLIPPER;
	var CLIPPED;
	var FOLDER;
}