package animate.internal;

import animate.FlxAnimateJson.FrameJson;
import animate.internal.elements.AtlasInstance;
import animate.internal.elements.ButtonInstance;
import animate.internal.elements.Element;
import animate.internal.elements.MovieClipInstance;
import animate.internal.elements.SymbolInstance;
import animate.internal.elements.TextFieldInstance;
import animate.internal.filters.Blend;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import openfl.media.Sound;

using StringTools;

#if (flixel >= "5.3.0")
import flixel.sound.FlxSound;
#else
import flixel.system.FlxSound;
#end

@:access(animate.FlxAnimateFrames)
@:allow(animate.internal.Layer)
class Frame implements IFlxDestroyable
{
	public var layer(default, null):Null<Layer>;
	public var elements(default, null):Array<Element>;
	public var index:Int;
	public var duration:Int;
	public var name:String;
	public var sound:Null<FlxSound>;
	public var blend:BlendMode;

	public function new(?layer:Layer)
	{
		this.elements = [];
		this.name = "";
		this.layer = layer;
		this.duration = 1;
		this.index = 0;
	}

	public function add(element:Element):Void
	{
		if (elements.indexOf(element) != -1)
			return;

		element.parentFrame = this;
		elements.push(element);
		setDirty();
	}

	public function insert(index:Int, element:Element)
	{
		if (elements.indexOf(element) != -1)
			return;

		element.parentFrame = this;
		elements.insert(index, element);
		setDirty();
	}

	public function setDirty()
	{
		if (_requireBake)
		{
			_dirty = true;
		}

		if (_bakedFrames != null)
		{
			_bakedFrames.dispose();
			_bakedFrames = null;
			_bakedIndices = null;
		}

		if (layer != null && layer.timeline != null)
			layer.timeline.parent.setSymbolDirty(layer.timeline.name);
	}

	@:access(animate.internal.Layer)
	public function convertToSymbol(fromIndex:Int, toIndex:Int, ?type:ElementType = GRAPHIC):SymbolInstance
	{
		var elements = this.elements.splice(fromIndex, toIndex - fromIndex);

		var timeline = new animate.internal.Timeline(null, layer.timeline.parent, "tempSymbol");
		var layer = new Layer(timeline);

		var frame = new Frame(layer);
		for (element in elements)
			frame.add(element);

		layer.frames.push(frame);
		layer.frameIndices.push(0);

		timeline.layers.push(layer);
		timeline.frameCount = layer.frameCount;

		var item = new SymbolItem(timeline);
		var instance = item.createInstance(type);
		insert(fromIndex, instance);

		return instance;
	}

	public function forEachElement(callback:Element->Void):Void
	{
		for (element in this.elements)
			callback(element);
	}

	public function getBounds(frameIndex:Int, ?rect:FlxRect, ?matrix:FlxMatrix, ?includeFilters:Bool = true, ?useCachedBounds:Bool = false):FlxRect
	{
		rect ??= FlxRect.get();
		rect.set();

		if (elements.length <= 0)
		{
			(matrix != null) ? rect.set(matrix.tx, matrix.ty, 0, 0) : rect.set(0, 0, 0, 0);
			return rect;
		}

		var tmpRect = FlxRect.get();

		rect = elements[0].getBounds(frameIndex, rect, matrix, includeFilters, useCachedBounds);
		for (i in 1...elements.length)
		{
			tmpRect = elements[i].getBounds(frameIndex, tmpRect, matrix, includeFilters, useCachedBounds);
			rect = Timeline.expandBounds(rect, tmpRect);
		}

		if (this.layer.layerType == CLIPPED && this.layer.parentLayer != null)
		{
			tmpRect.set();
			// 【修复】剥离绝对帧污染
			var maskerBounds = this.layer.parentLayer.getBounds(frameIndex, tmpRect, matrix, includeFilters, useCachedBounds);
			Timeline.maskBounds(rect, maskerBounds);
		}

		tmpRect.put();
		return rect;
	}

	public inline function iterator()
	{
		return elements.iterator();
	}

	public inline function keyValueIterator()
	{
		return elements.keyValueIterator();
	}

	@:allow(animate.internal.Layer)
	function _loadJson(frame:FrameJson, parent:FlxAnimateFrames):Void
	{
		this.index = frame.I;
		this.duration = frame.DU;
		this.name = frame.N ?? "";
		this.blend = #if flash animate.internal.filters.Blend.fromInt(frame.B) #else frame.B #end;

		var e = frame.E;
		if (e != null)
		{
			for (element in e)
			{
				var si = element.SI;
				if (si != null)
				{
					this.elements.push(switch (si.ST)
					{
						case "B" | "button":
							new ButtonInstance(si, parent, this);
						case "MC" | "movieclip":
							new MovieClipInstance(si, parent, this);
						default:
							new SymbolInstance(si, parent, this);
					});
				}
				else
				{
					var asi = element.ASI;
					if (asi != null)
					{
						this.elements.push(new AtlasInstance(asi, parent, this));
					}
					else
					{
						var tfi = element.TFI;
						if (tfi != null)
						{
							this.elements.push(new TextFieldInstance(tfi, parent, this));
						}
					}
				}
			}
		}

		if (frame.SND != null)
		{
			final soundPath:String = parent.path + '/LIBRARY/' + frame.SND.N;

			#if (cpp || hl)
			if (soundPath.endsWith(".wav"))
			{
				var bytes = FlxAnimateAssets.getBytes(soundPath);
				var buffer = lime.media.AudioBuffer.fromBytes(bytes);
				var openflSound = Sound.fromAudioBuffer(buffer);
				sound = FlxG.sound.load(openflSound);
				return;
			}
			#end

			sound = FlxG.sound.load(soundPath);
		}
	}

	@:allow(animate.internal.Layer)
	var _dirty:Bool = false;

	@:allow(animate.internal.Layer)
	var _requireBake:Bool = false;

	var _bakedFrames:BakedFramesVector;
	var _bakedIndices:Array<Int>;

	function _bakeFrame(frameIndex:Int):Void
	{
		if (layer.parentLayer == null)
		{
			_dirty = false;
			return;
		}

		if (_bakedFrames == null)
			_bakedFrames = new BakedFramesVector(duration);

		if (_bakedIndices == null)
		{
			var isSimpleRender:Bool = true;
			for (element in elements)
			{
				if (element is AtlasInstance)
					continue;

				if (!element.toSymbolInstance().isSimpleSymbol())
				{
					isSimpleRender = false;
					break;
				}
			}

			_bakedIndices = isSimpleRender ? [for (i in 0...duration) 0] : [for (i in 0...duration) i];
		}

		// 防止数组越界
		var safeIndex = frameIndex % _bakedIndices.length;
		if (safeIndex < 0) safeIndex += _bakedIndices.length;
		safeIndex = _bakedIndices[safeIndex];

		if (_bakedFrames[safeIndex] != null)
			return;

		// 【修复】剥离绝对帧，传入安全的相对帧
		var bakedFrame:Null<AtlasInstance> = FilterRenderer.maskFrame(this, safeIndex, layer);
		if (bakedFrame == null)
			return;

		bakedFrame.parentFrame = this;
		_bakedFrames[safeIndex] = bakedFrame;

		if (bakedFrame.frame == null || bakedFrame.frame.frame.isEmpty)
			bakedFrame.visible = false;

		if (_dirty && _bakedFrames.isFull())
			_dirty = false;
	}

	@:allow(animate.internal.elements.SymbolInstance)
	@:allow(animate.internal.FilterRenderer)
	@:allow(animate.internal.filters.Blend)
	@:allow(animate.internal.elements.AtlasInstance)
	private static var __isDirtyCall:Bool = false;

	public function draw(camera:FlxCamera, currentFrame:Int, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool,
			?shader:FlxShader):Void
	{
		var blend = Blend.resolve(this.blend, blend);

		// 【修复核心】彻底切断 currentFrame - this.index，计算出纯粹的安全帧
		var safeFrame = currentFrame - this.index;
		if (safeFrame < 0) safeFrame = 0;
		
		var wrappedFrame = safeFrame % duration;
		if (wrappedFrame < 0) wrappedFrame += duration;

		if (_dirty)
		{
			if (layer != null)
				_bakeFrame(wrappedFrame);
		}

		if (_bakedFrames != null)
		{
			var bakedFrame = _bakedFrames[_bakedIndices[wrappedFrame]];
			if (bakedFrame != null)
			{
				if (bakedFrame.visible)
					// 传 0 避免下级污染
					bakedFrame.draw(camera, wrappedFrame, 0, parentMatrix, transform, blend, antialiasing, shader);
				return;
			}
		}

		// 【修复核心】在这里把绝对偏移滤掉，传相对索引给下级
		_drawElements(camera, wrappedFrame, parentMatrix, transform, blend, antialiasing, shader);
	}

	@:allow(animate.internal.FilterRenderer)
	inline function _drawElements(camera:FlxCamera, currentFrame:Int, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool,
			?shader:FlxShader)
	{
		for (element in elements)
		{
			if (element.visible)
				// 【修复】把 frameIndex 改为 0，彻底切断 377 往下传递
				element.draw(camera, currentFrame, 0, parentMatrix, transform, blend, antialiasing, shader);
		}
	}

	public function destroy():Void
	{
		elements = FlxDestroyUtil.destroyArray(elements);
		sound = FlxDestroyUtil.destroy(sound);
		layer = null;

		if (_bakedFrames != null)
		{
			_bakedFrames.dispose();
			_bakedFrames = null;
		}
	}

	public function toString():String
	{
		return '{name: "$name", index: $index, duration: $duration}';
	}
}

extern abstract BakedFramesVector(Array<AtlasInstance>)
{
	public inline function new(length:Int)
	{
		#if cpp
		this = cpp.NativeArray.create(length);
		#else
		this = [];
		for (i in 0...length)
			this.push(null);
		#end
	}

	public inline function isFull():Bool
	{
		return this.indexOf(null) == -1;
	}

	public inline function setNull(index:Int):Void
	{
		var frame = get(index);
		if (frame == null)
			return;

		if (frame.frame != null)
		{
			frame.frame.parent = FlxDestroyUtil.destroy(frame.frame.parent);
			frame.frame = FlxDestroyUtil.destroy(frame.frame);
		}

		set(index, FlxDestroyUtil.destroy(frame));
	}

	public inline function dispose():Void
	{
		for (i in 0...this.length)
			setNull(i);
	}

	public inline function findFrame(index:Int):Null<AtlasInstance>
	{
		final max:Int = this.length - 1;
		final lowerBound:Int = (index < 0) ? 0 : index;
		return get((lowerBound > max) ? max : lowerBound);
	}

	@:arrayAccess
	public inline function get(index:Int):AtlasInstance
		return #if cpp cpp.NativeArray.unsafeGet(this, index) #else this[index] #end;

	@:arrayAccess
	public inline function set(index:Int, value:AtlasInstance):AtlasInstance
		return #if cpp cpp.NativeArray.unsafeSet(this, index, value) #else this[index] = value #end;
}