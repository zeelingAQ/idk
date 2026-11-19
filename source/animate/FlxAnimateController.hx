package animate;

import animate.internal.Timeline;
import flixel.FlxG;
import flixel.animation.FlxAnimation;
import flixel.animation.FlxAnimationController;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;
using StringTools;

@:access(animate.FlxAnimate)
class FlxAnimateController extends FlxAnimationController
{
	public final onFrameLabel = new FlxTypedSignal<(frameLabel:String) -> Void>();

	public function new(sprite:FlxAnimate) super(sprite);

	public function addByFrameLabel(name:String, label:String, ?frameRate:Float, ?looped:Bool = true, ?flipX:Bool, ?flipY:Bool, ?timeline:Timeline):Void
	{
		if (!hasAnimateAtlas) return;
		var usedTimeline = timeline ?? getDefaultTimeline();
		var foundFrames = findFrameLabelIndices(label, usedTimeline);
		
		if (foundFrames.length <= 0) return;
		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, foundFrames, frameRate, looped, flipX, flipY);
		anim.timeline = usedTimeline;
		_animations.set(name, anim);
	}

	override function set_frameIndex(frame:Int):Int
	{
		if (!isAnimate) return super.set_frameIndex(frame);

		var curAnim:Null<FlxAnimateAnimation> = cast _curAnim;
		if (curAnim != null)
		{
			final numFrames = #if (flixel >= "5.4.0") numFrames #else curAnim.timeline.frameCount #end;
			if (numFrames > 0)
			{
				// 【重写点】严格将帧索引限制在安全范围内，防止越界传到底层
				frame = frame % numFrames;

				_animate.timeline = curAnim.timeline;
				_animate.timeline.currentFrame = frame;
				_animate.timeline.signalFrameChange(frame, this);
				if (_animate.useRenderTexture) _animate._renderTextureDirty = true;
				
				frameIndex = frame;
				fireCallback();
				updateTimelineBounds();
			}
		}
		return frameIndex;
	}

	var animateFrame:FlxFrame;

	@:allow(animate.FlxAnimate)
	function updateTimelineBounds():Void
	{
		if (animateFrame == null)
		{
			@:privateAccess animateFrame = new FlxFrame(_animate.graphic);
			animateFrame.frame = FlxRect.get();
		}
		@:privateAccess var bounds = _animate.timeline._bounds;
		animateFrame.parent = _animate.graphic;
		animateFrame.sourceSize.set(bounds.width, bounds.height);

		if (_animate.applyStageMatrix)
		{
			animateFrame.sourceSize.x *= _animate.library.matrix.a;
			animateFrame.sourceSize.y *= _animate.library.matrix.d;
		}
		animateFrame.frame.copyFrom(bounds);
		animateFrame.uv.set(0, 0, bounds.width, bounds.height);
		_animate.frame = animateFrame;
	}

	override function play(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0)
	{
		var anim = _animations.get(animName);
		if (anim != null)
		{
			@:privateAccess _animate.isAnimate = anim is FlxAnimateAnimation;
		}
		super.play(animName, force, reversed, frame);
	}

	var isAnimate(get, never):Bool;
	var hasAnimateAtlas(get, never):Bool;
	public inline function getDefaultFramerate():Float return hasAnimateAtlas ? _animate.library.frameRate : 0.0;
	public inline function getDefaultTimeline():Timeline return hasAnimateAtlas ? _animate.library.timeline : null;

	var _animate(get, never):FlxAnimate;
	inline function get__animate():FlxAnimate return cast _sprite;
	inline function get_isAnimate():Bool return _animate.isAnimate;
	inline function get_hasAnimateAtlas():Bool return _animate.library != null;

	override function destroy()
	{
		super.destroy();
		animateFrame = FlxDestroyUtil.destroy(animateFrame);
		FlxDestroyUtil.destroy(onFrameLabel);
	}
}

class FlxAnimateAnimation extends FlxAnimation
{
	public var timeline:Timeline;

	#if (flixel >= "5.3.0")
	override function getCurrentFrameDuration():Float return frameDuration;
	#end

	override function destroy()
	{
		super.destroy();
		timeline = null;
	}
}