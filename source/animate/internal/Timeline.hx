package animate.internal;

import animate.FlxAnimateJson.TimelineJson;
import animate.internal.elements.Element;
import flixel.FlxCamera;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil;
import flixel.util.typeLimit.OneOfTwo;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

using StringTools;

@:access(openfl.geom.Point)
@:access(openfl.geom.Matrix)
@:access(flixel.graphics.frames.FlxFrame)
@:allow(animate.FlxAnimate)
class Timeline implements IFlxDestroyable
{
	public var libraryItem:SymbolItem;
	public var layers:Array<Layer>;
	public var name:String;
	public var currentFrame:Int;
	public var frameCount:Int;
	public var parent(default, null):FlxAnimateFrames;

	var _layerMap:Map<String, Layer>;
	var _bounds:FlxRect;

	public function new(?timeline:TimelineJson, parent:FlxAnimateFrames, ?name:String)
	{
		this.name = name ?? "";
		this.layers = [];
		this.currentFrame = 0;
		this.parent = parent;

		_layerMap = [];
		_bounds = FlxRect.get();

		if (timeline != null)
			_loadJson(timeline);
	}

	public function getLayer(name:OneOfTwo<Int, String>):Null<Layer>
	{
		return (name is String) ? _layerMap.get(name) : layers[name];
	}

	public function forEachLayer(callback:Layer->Void):Void
	{
		for (layer in layers)
			callback(layer);
	}

	public function getFramesAtIndex(index:Int):Array<Frame>
	{
		var frames:Array<Frame> = [];
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(index);
			if (frame != null)
				frames.push(frame);
		}
		return frames;
	}

	public function getElementsAtIndex(index:Int):Array<Element>
	{
		var elements:Array<Element> = [];
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(index);
			if (frame != null)
			{
				for (element in frame.elements)
					elements.push(element);
			}
		}
		return elements;
	}

	public function getCurrentElements():Array<Element>
	{
		return getElementsAtIndex(currentFrame);
	}

	public function getFrameLabelAtIndex(index:Int):String
	{
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(index);
			if (frame != null && frame.name.length > 0)
				return frame.name;
		}
		return "";
	}

	public function findFrameLabelIndices(label:String):Array<Int>
	{
		var foundFrames:Array<Int> = [];
		var hasFoundLabel:Bool = false;

		for (layer in layers)
		{
			for (frame in layer.frames)
			{
				if (frame.name.rtrim() == label)
				{
					hasFoundLabel = true;

					for (i in 0...frame.duration)
						foundFrames.push(frame.index + i);
				}
			}

			if (hasFoundLabel)
				break;
		}

		return foundFrames;
	}

	public function getBoundsOrigin(?result:FlxPoint, ?applyStageMatrix:Bool = false):FlxPoint
	{
		result ??= FlxPoint.get();
		result.set(_bounds.x, _bounds.y);

		if (applyStageMatrix && parent?.matrix != null)
		{
			result.x *= parent.matrix.a;
			result.y *= parent.matrix.d;
		}

		return result;
	}

	public function getWholeBounds(?includeHiddenLayers:Bool = false, ?rect:FlxRect, ?matrix:FlxMatrix, ?includeFilters:Bool = true):FlxRect
	{
		var first:Bool = true;
		var tmpRect:FlxRect = FlxRect.get();
		rect ??= FlxRect.get();

		for (i in 0...this.frameCount)
		{
			var frameBounds = getBounds(i, includeHiddenLayers, tmpRect, null, includeFilters, true);
			if (frameBounds.isEmpty)
				continue;

			if (first)
			{
				rect.copyFrom(frameBounds);
				first = false;
			}
			else
				rect = expandBounds(rect, frameBounds);
		}

		applyMatrixToRect(rect, matrix);

		tmpRect.put();
		return rect;
	}

	var _cachedBounds:Map<Int, FlxRect> = [];

	public function getBounds(frameIndex:Int, ?includeHiddenLayers:Bool = false, ?rect:FlxRect, ?matrix:FlxMatrix, ?includeFilters:Bool = true,
			?useCachedBounds:Bool = false):FlxRect
	{
		rect ??= FlxRect.get();
		rect.set();

		if (useCachedBounds)
		{
			if (_cachedBounds.exists(frameIndex))
			{
				rect.copyFrom(_cachedBounds.get(frameIndex));
				return applyMatrixToRect(rect, matrix);
			}
		}

		var first:Bool = true;
		var tmpRect:FlxRect = FlxRect.get();

		for (layer in layers)
		{
			if (!layer.visible && !includeHiddenLayers)
				continue;

			var frame = layer.getFrameAtIndex(frameIndex);
			if (frame == null || frame.elements.length <= 0)
				continue;

			var frameBounds = frame.getBounds((frameIndex - frame.index), tmpRect, null, includeFilters, useCachedBounds);
			if (frameBounds.isEmpty)
				continue;

			if (first)
			{
				first = false;
				rect.copyFrom(frameBounds);
			}
			else
				expandBounds(rect, frameBounds);
		}

		applyMatrixToRect(rect, matrix);

		if (useCachedBounds)
			_cachedBounds.set(frameIndex, rect.copyTo(FlxRect.get()));

		tmpRect.put();
		return rect;
	}

	public function clearBoundsCache():Void
	{
		for (i in _cachedBounds.iterator())
			i.put();
		_cachedBounds.clear();
	}

	public inline function iterator()
	{
		return layers.iterator();
	}

	public inline function keyValueIterator()
	{
		return layers.keyValueIterator();
	}

	@:allow(animate.FlxAnimateController)
	private function signalFrameChange(frameIndex:Int, animation:FlxAnimateController):Void
	{
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(frameIndex);
			if (frame != null)
			{
				var isKeyFrame:Bool = (frame.index == frameIndex);
				if (isKeyFrame)
				{
					if (frame.sound != null)
						frame.sound.play(true);

					if (frame.name.length > 0)
						animation.onFrameLabel.dispatch(frame.name);
				}
			}
		}
	}

	public function draw(camera:FlxCamera, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool, ?shader:FlxShader)
	{
		if (currentFrame < 0)
			return;

		var i = layers.length - 1;
		while (i >= 0)
		{
			var layer = layers[i--];
			if (!layer.visible)
				continue;

			var frame = layer.getFrameAtIndex(currentFrame);
			if (frame == null)
				continue;

			frame.draw(camera, currentFrame, parentMatrix, transform, blend, antialiasing, shader);
		}
	}

	function _loadJson(timeline:TimelineJson)
	{
		var layersJson = timeline.L;

		for (layerJson in layersJson)
		{
			var layer = new Layer(this);
			layer.name = layerJson.LN;
			layers.push(layer);
			_layerMap.set(layer.name, layer);
		}

		for (i in 0...layersJson.length)
		{
			var layer = layers[i];
			layer._loadJson(layersJson[i], parent, i, layers);

			if (layer.frameCount > frameCount)
				frameCount = layer.frameCount;
		}

		_bounds = getWholeBounds(false, _bounds);
	}

	public function destroy():Void
	{
		parent = null;
		libraryItem = null;
		layers = FlxDestroyUtil.destroyArray(layers);
		_bounds = FlxDestroyUtil.put(_bounds);
		_layerMap = null;

		if (_cachedBounds != null)
		{
			clearBoundsCache();
			_cachedBounds = null;
		}
	}

	public function toString():String
	{
		return '{name: $name, frameCount: $frameCount}';
	}

	@:noCompletion
	public static inline function expandBounds(baseBounds:FlxRect, expandedBounds:FlxRect):FlxRect
	{
		var x = Math.min(baseBounds.x, expandedBounds.x);
		var y = Math.min(baseBounds.y, expandedBounds.y);
		var w = Math.max(baseBounds.right, expandedBounds.right) - x;
		var h = Math.max(baseBounds.bottom, expandedBounds.bottom) - y;

		baseBounds.set(x, y, w, h);
		return baseBounds;
	}

	@:noCompletion
	public static inline function maskBounds(masked:FlxRect, masker:FlxRect):FlxRect
	{
		if (masker.isEmpty)
			return masked;

		var x1:Float = Math.max(masked.x, masker.x);
		var y1:Float = Math.max(masked.y, masker.y);
		var x2:Float = Math.min(masked.right, masker.right);
		var y2:Float = Math.min(masked.bottom, masker.bottom);

		if (x2 <= x1 || y2 <= y1)
		{
			masked.set(0.0, 0.0, 0.0, 0.0);
			return masked;
		}

		masked.set(x1, y1, x2 - x1, y2 - y1);
		return masked;
	}

	@:noCompletion
	public static function applyMatrixToRect(rect:FlxRect, ?m:FlxMatrix):FlxRect
	{
		if (m == null)
			return rect;

		if (rect.isEmpty)
			return rect.set(m.tx, m.ty, 0, 0);

		var tx0 = m.a * rect.left + m.c * rect.top;
		var tx1 = tx0;
		var ty0 = m.b * rect.left + m.d * rect.top;
		var ty1 = ty0;

		var tx = m.a * rect.right + m.c * rect.top;
		var ty = m.b * rect.right + m.d * rect.top;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * rect.right + m.c * rect.bottom;
		ty = m.b * rect.right + m.d * rect.bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * rect.left + m.c * rect.bottom;
		ty = m.b * rect.left + m.d * rect.bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		rect.set(tx0 + m.tx, ty0 + m.ty, tx1 - tx0, ty1 - ty0);
		return rect;
	}
}