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

using StringTools;

@:access(animate.FlxAnimateFrames)
@:allow(animate.internal.Layer)
class Frame implements IFlxDestroyable
{
	public var layer(default, null):Null<Layer>;
	public var elements(default, null):Array<Element>;
	public var index:Int; // 现在这个完全由 Layer 赋值，永远从 0 开始
	public var duration:Int;
	public var name:String;
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
		if (elements.indexOf(element) != -1) return;
		element.parentFrame = this;
		elements.push(element);
		setDirty();
	}

	public function insert(index:Int, element:Element)
	{
		if (elements.indexOf(element) != -1) return;
		element.parentFrame = this;
		elements.insert(index, element);
		setDirty();
	}

	public function setDirty()
	{
		if (_requireBake) _dirty = true;
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
	function _loadJson(frame:FrameJson, parent:FlxAnimateFrames):Void
	{
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
						case "B" | "button": new ButtonInstance(si, parent, this);
						case "MC" | "movieclip": new MovieClipInstance(si, parent, this);
						default: new SymbolInstance(si, parent, this);
					});
				}
				else
				{
					var asi = element.ASI;
					if (asi != null) this.elements.push(new AtlasInstance(asi, parent, this));
					else
					{
						var tfi = element.TFI;
						if (tfi != null) this.elements.push(new TextFieldInstance(tfi, parent, this));
					}
				}
			}
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

		if (_bakedFrames == null) _bakedFrames = new BakedFramesVector(duration);
		if (_bakedIndices == null)
		{
			var isSimpleRender:Bool = true;
			for (element in elements)
			{
				if (element is AtlasInstance) continue;
				if (!element.toSymbolInstance().isSimpleSymbol())
				{
					isSimpleRender = false;
					break;
				}
			}
			_bakedIndices = isSimpleRender ? [for (i in 0...duration) 0] : [for (i in 0...duration) i];
		}

		// 绝对安全：强制限制在数组范围内
		var safeFrame = frameIndex % duration;
		if (safeFrame < 0) safeFrame += duration;
		if (safeFrame >= _bakedIndices.length) safeFrame = _bakedIndices.length - 1;

		safeFrame = _bakedIndices[safeFrame];
		if (_bakedFrames[safeFrame] != null) return;

		var bakedFrame:Null<AtlasInstance> = FilterRenderer.maskFrame(this, safeFrame, layer);
		if (bakedFrame == null) return;

		bakedFrame.parentFrame = this;
		_bakedFrames[safeFrame] = bakedFrame;

		if (bakedFrame.frame == null || bakedFrame.frame.frame.isEmpty) bakedFrame.visible = false;
		if (_dirty && _bakedFrames.isFull()) _dirty = false;
	}

	public function draw(camera:FlxCamera, currentFrame:Int, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool, ?shader:FlxShader):Void
	{
		var blend = Blend.resolve(this.blend, blend);

		// 重写点：彻底剥夺当前帧的绝对属性，强制用 duration 取余
		var safeFrame = currentFrame % duration;
		if (safeFrame < 0) safeFrame += duration;

		if (_dirty && layer != null) _bakeFrame(safeFrame);

		if (_bakedFrames != null)
		{
			var bakedFrame = _bakedFrames[_bakedIndices[safeFrame]];
			if (bakedFrame != null)
			{
				if (bakedFrame.visible)
					bakedFrame.draw(camera, safeFrame, 0, parentMatrix, transform, blend, antialiasing, shader);
				return;
			}
		}

		// 重写点：传 0 给子元素，切断一切绝对帧污染
		for (element in elements)
		{
			if (element.visible)
				element.draw(camera, safeFrame, 0, parentMatrix, transform, blend, antialiasing, shader);
		}
	}

	public function destroy():Void
	{
		elements = FlxDestroyUtil.destroyArray(elements);
		layer = null;
		if (_bakedFrames != null)
		{
			_bakedFrames.dispose();
			_bakedFrames = null;
		}
	}
}