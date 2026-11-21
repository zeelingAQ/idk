import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.text.FlxTextAlign;
import flixel.text.FlxTextBorderStyle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTweenType;
import flixel.util.FlxAxes;
import flixel.addons.display.FlxBackdrop;
import openfl.display.BlendMode;
import util.GenUtil;
import funkin.backend.utils.DiscordUtil;
import mobile.funkin.backend.utils.TouchUtil;

var start1Sound:FlxSound;
var start2Sound:FlxSound;
var skyBG:FunkinSprite;
var hqSpr:FunkinSprite;
var dust:FlxBackdrop;
var starStart:FlxSprite;
var starStartGlow:FlxSprite;
var zoomTween:FlxTween;
var whiteOverlay:FlxSprite;
var canContinue:Bool = false;
var transitioning:Bool = false;

function create()
{
	DiscordUtil.changePresenceSince("In Title", null);
	if (FlxG.sound.music != null)
		FlxG.sound.music.stop();

	start1Sound = new FlxSound().loadEmbedded(Paths.sound('ui/ui_start1'));
	FlxG.sound.list.add(start1Sound);

	start2Sound = new FlxSound().loadEmbedded(Paths.sound('ui/ui_start2'));
	FlxG.sound.list.add(start2Sound);

	hqSpr = new FunkinSprite(0, 0).loadGraphic(Paths.image('ui/title/keyart'));
	hqSpr.scale.set(1.1, 1.1);
	add(hqSpr);
	hqSpr.screenCenter();

	hqSpr.visible = false;

	bg_Logo = new FunkinSprite(110, 35).loadGraphic(Paths.image('ui/main/logo'));
	add(bg_Logo);
	bg_Logo.scale.set(1.35, 1.35);

	bg_Logo.visible = false;

	pressStartBG = new FlxBackdrop(Paths.image('ui/title/pressstartbg'), FlxAxes.X, 0, 0);
	add(pressStartBG);
	pressStartBG.blend = BlendMode.ADD;
	pressStartBG.y = 900;
	pressStartBG.velocity.set(25, 0);

	pressStartPixelsTxt = new FlxText(0, 0, 0, i18n.tr('Title/PressConfirm'));
	pressStartPixelsTxt.setFormat(Paths.font("shingo.otf"), 32, FlxColor.BLACK, FlxTextAlign.CENTER);
	pressStartPixelsTxt.drawFrame(true);

	pressStartBGTxt = new FlxBackdrop(pressStartPixelsTxt.graphic, FlxAxes.X, 25, 0);
	add(pressStartBGTxt);
	pressStartBGTxt.y = 913;
	pressStartBGTxt.velocity.set(25, 0);
	pressStartBGTxt.alpha = 0.5;

	pressStartTxt = new FlxText(0, 908, 0, '- ' + i18n.tr('Title/PressConfirm') + ' -');
	pressStartTxt.setFormat(Paths.font("shingo.otf"), 42, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, 0x88000000);
	pressStartTxt.borderSize = 2.5;
	add(pressStartTxt);
	pressStartTxt.screenCenter(FlxAxes.X);

	pressStartBG.visible = false;
	pressStartBGTxt.visible = false;
	pressStartTxt.visible = false;

	// STAR INTRO
	starStart = new FlxSprite().loadGraphic(Paths.image('ui/title/star'));
	add(starStart);
	starStart.screenCenter();
	starStart.alpha = 0.0;

	starStartGlow = new FlxSprite().loadGraphic(Paths.image('ui/title/glow'));
	add(starStartGlow);
	starStartGlow.scale.set(0.75, 0.75);
	starStartGlow.screenCenter();
	starStartGlow.blend = BlendMode.ADD;
	starStartGlow.alpha = 0.0;

	whiteOverlay = new FlxSprite(-FlxG.width * 2, -FlxG.height * 2).makeGraphic(FlxG.width * 6, FlxG.height * 6, FlxColor.WHITE);
	whiteOverlay.alpha = 0.0001;
	add(whiteOverlay);
	whiteOverlay.blend = BlendMode.ADD;
	whiteOverlay.alpha = 0.0;

	FlxG.camera.zoom = 1.0;

	new FlxTimer().start(1.0, function(tmr:FlxTimer)
	{
		if (start1Sound == null)
			tmr.reset();
		else
			startIntro();
	});
}

function update(elapsed:Float)
{
	if (canContinue && !transitioning && (controls.ACCEPT || TouchUtil.justPressed))
	{
		transitioning = true;
		GenUtil.playUISound('confirm');

		goIntoMenu();
	}
}

function goIntoMenu()
{
	FlxG.camera.zoom = 1.05;
	zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1.0}, 0.75, {
		ease: FlxEase.quadOut,
		onComplete: function(twn:FlxTween)
		{
			whiteOverlay.blend = BlendMode.NORMAL;
			whiteOverlay.alpha = 0.0;
			whiteOverlay.color = FlxColor.BLACK;

			FlxTween.tween(whiteOverlay, {alpha: 1.0}, 1.0, {ease: FlxEase.quadIn});

			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 2.5}, 1.0, {
				ease: FlxEase.expoIn,
				onComplete: function(twn:FlxTween)
				{
					FlxG.switchState(new MainMenuState());
				}
			});
		}
	});
}

function startIntro()
{
	start1Sound?.play();

	FlxTween.tween(starStart, {alpha: 1.0}, 0.20, {ease: FlxEase.quadOut});

	FlxTween.tween(bg_Logo, {y: bg_Logo.y + 5}, 5.0, {ease: FlxEase.quadInOut, type: FlxTween.PINGPONG});

	FlxG.camera.zoom = 1.00;
	zoomTween = FlxTween.tween(FlxG.camera, {zoom: 6.0, angle: 90}, 1.75, {
		ease: FlxEase.expoIn,
		startDelay: 0.5,
		onComplete: function(twn:FlxTween)
		{
			zoomTween = null;
		}
	});

	FlxTween.tween(starStartGlow, {alpha: 1.0}, 2.3, {ease: FlxEase.quadOut, startDelay: 0.7});
	if (Options.flashingLights)
		FlxTween.tween(whiteOverlay, {alpha: 1.0}, 0.35, {ease: FlxEase.expoIn, startDelay: 1.85});

	start1Sound.onComplete = function()
	{
		start2Sound.play();
		start1Sound.pause();
		if (FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('menu'), 0.7);
		else if (FlxG.sound.music.name != 'menu')
			FlxG.sound.playMusic(Paths.music('menu'), 0.7);

		showTitle();
	};
}

function showTitle()
{
	hqSpr.visible = true;
	bg_Logo.visible = true;
	FlxG.camera.angle = 0;

	pressStartBG.visible = true;
	pressStartBGTxt.visible = true;
	pressStartTxt.visible = true;

	if (Options.flashingLights)
	{
		FlxTween.completeTweensOf(whiteOverlay);
		whiteOverlay.alpha = 1.0;
		FlxTween.tween(whiteOverlay, {alpha: 0.0}, 0.75, {ease: FlxEase.quadOut});
	}

	starStart.visible = false;
	starStartGlow.visible = false;

	zoomTween?.cancel();
	FlxG.camera.zoom = 1.25;
	zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1.0}, 1.5, {
		ease: FlxEase.expoOut,
		onComplete: function(twn:FlxTween)
		{
			zoomTween = null;
			canContinue = true;
		}
	});

	FlxTween.tween(pressStartTxt, {alpha: 1.0}, 0.75, {ease: FlxEase.quadOut, startDelay: 1.5});
}
