import jsoni18n.I18n;
//import funkin.backend.utils.Translator;
import funkin.backend.MusicBeatTransition;
import funkin.menus.PauseSubState;
import funkin.backend.system.Flags;
import funkin.backend.system.framerate.Framerate;
import funkin.backend.system.Controls;
import gamejolt.GameJolt;
import gamejolt.GJRequest;
import gamejolt.types.RequestType;
import openfl.text.TextFormat;
import util.PopUpUtil;
import lime.app.Application;
import hxvlc.util.Handle;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.text.FlxTextAlign;
import flixel.text.FlxTextBorderStyle;
import ui.achievement.AchievementUnlockNoticeUI;
import funkin.backend.utils.HttpUtil;

var initData:Bool = false;
public static var achievementData:Map<String, Dynamic> = [];
public static var gauntletModsData:Map<String, Dynamic> = [];
public static var i18n:I18n;
public static var signedIntoGJ:Bool = false;
public static var versionNumber:String = '';
public static var newsText:String = '';
public static var thisVersionNumber:String = '1.0.7';
public static var reattemptConnection:Bool = true;
public static var onOutdatedBuild:Bool = false;
public static var lockGJprogression:Bool = false;

static var redirectStates:Map<FlxState, String> = [
	TitleState => "HQSetup",
	MainMenuState => "HQMainMenu",
	FreeplayState => "HQFreeplay",
	StoryMenuState => "HQMainMenu"
];

public static var globalCam:FlxCamera;
var applyToGroup:Bool = false;
var popupSprites:Array = [];

// Goduka
public static var godukaEnabled:Bool = false;
public static var godukaCooldown:Int = 0;

function new()
{
	Handle.init([]);
}

function preStateSwitch()
{
	if (!initData)
	{
		loadData();
		
		if (FlxG.save.data.curUserName != null)
			GameJolt.userName = FlxG.save.data.curUserName;
		if (FlxG.save.data.curUserToken != null)
			GameJolt.userToken = FlxG.save.data.curUserToken;

		var signInRequest:GJRequest = new GJRequest(RequestType.USER_AUTH);
		signInRequest.onComplete.add(function(res)
		{
			if (res.success == 'true')
			{
				signedIntoGJ = true;

				new FlxTimer().start(1.5, function(tmr:FlxTimer)
				{
					PopUpUtil.gjPopup(i18n.tr('GameJolt/SignedIn') + ' ${GameJolt.userName}');
				});
			}
		});
		signInRequest.onError.add(e -> trace('Failed: $e'));
		signInRequest.send(false);

		initData = true;

		var window = Application.current.window;

		var screenWidth = window.display.bounds.width;
		var screenHeight = window.display.bounds.height;

		/* if (screenWidth <= 1920 || screenHeight <= 1080)
		{
			window.width = screenWidth / 1.5;
			window.height = screenHeight / 1.5;
			window.x = Std.int((screenWidth - window.width) / 2);
			window.y = Std.int((screenHeight - window.height) / 2);
		}

		FlxG.sound.volume = 0.1; */

		FlxSoundTray.volumeUpChangeSFX = Paths.sound('ui/vol_up');
		FlxSoundTray.volumeDownChangeSFX = Paths.sound('ui/vol_down');
	}

	MusicBeatTransition.script = 'data/scripts/HQTransition';

	FlxSprite.defaultAntialiasing = Options.antialiasing;

	Options.P2_NOTE_LEFT = [];
	Options.P2_NOTE_DOWN = [];
	Options.P2_NOTE_UP = [];
	Options.P2_NOTE_RIGHT = [];
	Options.P2_DODGE = [];

	if (Options.language == 'en')
		Options.language = 'zh_cn';

	i18n = new I18n();
	i18n.loadFromString(Assets.getText('data/langs/${Options.language}/translations.json'));

	// Save data
	FlxG.save.data.tutorialCompleted ??= false;
	FlxG.save.data.kyubeyCoins ??= 0;
	FlxG.save.data.unlockedSongs ??= [];
	FlxG.save.data.unlockableSongs ??= [];

	FlxG.save.data.curStoryProgress ??= 0;
	FlxG.save.data.curStoryDiff ??= 'hard';

	FlxG.save.data.unlockedAchievements ??= [];
	FlxG.save.data.canUseGameJoltSync ??= true;

	FlxG.save.data.bestGauntletScoreStandard ??= 0;
	// FlxG.save.data.bestGauntletScoreEndless ??= 0;

	// GJ Stuff
	FlxG.save.data.curUserName ??= '';
	FlxG.save.data.curUserToken ??= '';

	// Achievement progress data
	FlxG.save.data.pinpointAccuracyProgress ??= 0;
	FlxG.save.data.devotedProgress ??= 0;

	// Startup
	FlxG.save.data.firstTimeSetupDone ??= false;
	FlxG.save.data.seeIntro ??= true;

	// Post Story mode content
	FlxG.save.data.freeplayUnlocked ??= false;
	FlxG.save.data.gauntletUnlocked ??= false;
	FlxG.save.data.accoladesUnlocked ??= false;
	FlxG.save.data.galleryUnlocked ??= false;

	FlxG.save.data.viewedMenu ??= [1, 2, 3, 4];

	FlxG.save.flush();

	for (redirectState in redirectStates.keys())
		if (FlxG.game._requestedState is redirectState)
			FlxG.game._requestedState = new ModState(redirectStates.get(redirectState));

	var nonModState:String = Type.getClassName(Type.getClass(FlxG.state));

	if (nonModState == 'funkin.game.PlayState')
	{
		applyToGroup = true;
	}
	else
	{
		applyToGroup = false;
	}

	var attemptDataFetch:Bool = false;

	if (ModState.lastName == 'HQMainMenu')
	{
		attemptDataFetch = true;
	}

	if (reattemptConnection && attemptDataFetch)
	{
		if (HttpUtil.hasInternet())
		{
			var liveData:String = HttpUtil.requestText("https://docs.google.com/document/d/1x60PXXBA4VXk9n0UNhKbrsTCDu4qKyPE73KSs9zDzTg/edit?usp=sharing");
			var hqData = liveData.split('[HQData]')[1].trim();
			versionNumber = hqData.split('{}')[0].trim();
			newsText = hqData.split('{}')[1].trim();
		}
		else
		{
			versionNumber = '';
			newsText = '';
			reattemptConnection = false;
		}

		if (thisVersionNumber == versionNumber)
			onOutdatedBuild = false;
		else if (HttpUtil.hasInternet())
			onOutdatedBuild = true;
		else
		{
			onOutdatedBuild = false;
			lockGJprogression = true;
			reattemptConnection = false;
		}
	}

	if (Options.devMode)
		onOutdatedBuild = false;
}

function postStateSwitch()
{
	Flags.DEFAULT_ICONBOP = false;
	Framerate.fpsCounter.fpsNum.defaultTextFormat = new TextFormat(Paths.getFontName(Paths.font('shingo.otf')), 18);
	Framerate.fpsCounter.fpsLabel.defaultTextFormat = new TextFormat(Paths.getFontName(Paths.font('shingo.otf')), 12);
	Framerate.memoryCounter.memoryText.defaultTextFormat = new TextFormat(Paths.getFontName(Paths.font('shingo.otf')), 12);
	Framerate.memoryCounter.memoryPeakText.defaultTextFormat = new TextFormat(Paths.getFontName(Paths.font('shingo.otf')), 10);
	Framerate.codenameBuildField.defaultTextFormat = new TextFormat(Paths.getFontName(Paths.font('shingo.otf')), 12);
	Flags.DEFAULT_CAM_ZOOM_MULT = 0.0075;
	Flags.DEFAULT_HUD_ZOOM_MULT = 0.015;
	Flags.DEFAULT_CAM_ZOOM_LERP = 0.025;
	Flags.DEFAULT_HUD_ZOOM_LERP = 0.025;
	Flags.DEFAULT_FONT = "vcr.ttf";
	Flags.DEFAULT_INTRO_SOUNDS = [];
	Flags.DEFAULT_MENU_MUSIC = "menu";
	Flags.DISABLE_LANGUAGES = true;
	Flags.DEFAULT_PAUSE_SCRIPT = 'data/states/HQPause';
	if (Options.devMode)
		Framerate.codenameBuildField.text = 'Vs Holy Quintet / ' + '(v$thisVersionNumber) / ' + Flags.COMMIT_MESSAGE;
	else
		Framerate.codenameBuildField.text = 'Vs Holy Quintet (v$thisVersionNumber)';

	Flags.DEFAULT_GITAROO = false;

	for (popup in popups)
	{
		new FlxTimer().start(3.0, function(tmr:FlxTimer)
		{
			FlxTween.tween(popup, {y: popup.y - 275}, 0.5, {
				ease: FlxEase.quadIn,
				onComplete: function(twn:FlxTween)
				{
					Main.instance.removeChild(popup);
					popups.remove(popup);
				}
			});
		});
	}

	Options.devMode = true;

	globalCam = new FlxCamera();
	FlxG.cameras.add(globalCam);
	globalCam.bgColor = 0x00000000;

	if (Options.devMode)
	{
		devText = new FlxText(0, 850, FlxG.width, 'Development\nBuild');
		devText.setFormat(Paths.font("shingo.otf"), 72, FlxColor.WHITE, FlxTextAlign.CENTER);
		devText.alpha = 0.05;
		FlxG.state.add(devText).cameras = [globalCam];
		devText.screenCenter();
	}

	var nonModState:String = Type.getClassName(Type.getClass(FlxG.state));

	if (nonModState == 'funkin.game.PlayState')
	{
		applyToGroup = true;
	}
	else
	{
		applyToGroup = false;
	}
}

var godMode:Bool = false;
var botPlay:Bool = false;
var highestPeak:Float = 0.0;
var oldVolume:Float = FlxG.sound.volume;

function update(elapsed:Float)
{
	FlxG.cameras.remove(globalCam, false);
	FlxG.cameras.add(globalCam, false);
// 放在 update() 里
if (PlayState.instance != null)
{
    if (PlayState.instance.player != null)
        PlayState.instance.player.cpu = true;   // 注意：= true，不是 = !xxx
    else
        PlayState.instance.cpu.cpu = true;
}
	if (Options.devMode)
	{
		if (elapsed > highestPeak)
		{
			highestPeak = elapsed;
			trace('NEW HIGHEST PEAK: ' + highestPeak);
		}

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT)
		{
			FlxG.timeScale = 15;
			if (PlayState.instance != null)
				PlayState.instance.health = 2;
		}
		else if (FlxG.keys.justReleased.CONTROL || FlxG.keys.justReleased.SHIFT)
		{
			FlxG.timeScale = 1;
		}
		if (PlayState.instance != null && FlxG.keys.justPressed.SEVEN)
		{
			PlayState.chartingMode = true;
		}
		if (PlayState.instance != null && FlxG.keys.justPressed.B)
		{
			if (PlayState.instance.player != null)
				PlayState.instance.player.cpu = !PlayState.instance.player.cpu;
			else
				PlayState.instance.cpu.cpu = !PlayState.instance.cpu.cpu;
		}
	}
}

public static function promptAchievementPopUp(achievement:String)
{
	if (ModState.lastName == 'HQGallery')
		return;

	var popup:AchievementUnlockNoticeUI = new AchievementUnlockNoticeUI(achievement);
	if (applyToGroup)
		FlxG.state.add(popup).group.cameras = [globalCam];
	else
		FlxG.state.add(popup).cameras = [globalCam];

	popupSprites.push(popup);

	popup.group.y += 150;

	for (popup in popupSprites)
	{
		popup.group.y -= 150;
	}
}

function loadData()
{
	achievementData.set('FCInitium', {
		nameKey: 'FCInitium',
		img: 'fc_initium',
		diff: 1,
		gjid: 294196
	});

	achievementData.set('FCResonance', {
		nameKey: 'FCResonance',
		img: 'fc_resonance',
		diff: 1,
		gjid: 307446
	});
	achievementData.set('FCPartea', {
		nameKey: 'FCPartea',
		img: 'fc_partea',
		diff: 1,
		gjid: 307447
	});
	achievementData.set('FCEternalStar', {
		nameKey: 'FCEternalStar',
		img: 'fc_eternalstar',
		diff: 1,
		gjid: 307448
	});
	achievementData.set('FCVexation', {
		nameKey: 'FCVexation',
		img: 'fc_vexation',
		diff: 1,
		gjid: 307449
	});
	achievementData.set('FCOutOfTime', {
		nameKey: 'FCOutOfTime',
		img: 'fc_outoftime',
		diff: 1,
		gjid: 307450
	});
	achievementData.set('CompleteAct1', {
		nameKey: 'CompleteAct1',
		img: 'clear_part1',
		diff: 1,
		gjid: 307452
	});
	achievementData.set('FCMeguca', {
		nameKey: 'FCMeguca',
		img: 'fc_meguca',
		diff: 1,
		gjid: 307453
	});
	achievementData.set('FCReconnect', {
		nameKey: 'FCReconnect',
		img: 'fc_reconnect',
		diff: 1,
		gjid: 307454
	});
	achievementData.set('FCStardom', {
		nameKey: 'FCStardom',
		img: 'fc_stardom',
		diff: 1,
		gjid: 307455
	});
	achievementData.set('ResOutheal', {
		nameKey: 'ResOutheal',
		img: 'resonance_outheal',
		diff: 0,
		gjid: 307458
	});
	achievementData.set('VexYikes', {
		nameKey: 'VexYikes',
		img: 'vexation_dodgeall',
		diff: 0,
		gjid: 307459
	});
	achievementData.set('YoureOnMyTime', {
		nameKey: 'YoureOnMyTime',
		img: 'outoftime_dodgeall',
		diff: 0,
		gjid: 307460
	});
	achievementData.set('TimeWaitsForMe', {
		nameKey: 'TimeWaitsForMe',
		img: 'outoftime_pause',
		diff: 0,
		gjid: 307461
	});
	achievementData.set('Tenacious', {
		nameKey: 'Tenacious',
		img: 'general_restart',
		diff: 0,
		gjid: 307462
	});
	achievementData.set('ThanksForPlaying', {
		nameKey: 'ThanksForPlaying',
		img: 'general_visitcredits',
		diff: 0,
		gjid: 307463
	});
	achievementData.set('ChamberOfLight', {
		nameKey: 'ChamberOfLight',
		img: 'general_visitgallery',
		diff: 0,
		gjid: 307464
	});
	/*
		achievementData.set('FourFourFour', {
			nameKey: 'FourFourFour',
			img: 'secret_444',
			diff: 0,
			gjid: -1
		});
	 */
	achievementData.set('PinpointAccuracy', {
		nameKey: 'PinpointAccuracy',
		img: 'general_pinpoint',
		diff: 1,
		gjid: 307456,
		trackerGoal: 5000
	});
	achievementData.set('Devoted', {
		nameKey: 'Devoted',
		img: 'general_devoted',
		diff: 1,
		gjid: 307457,
		trackerGoal: 25
	});

	// Gauntlet Mods
	gauntletModsData.set('PerformanceRegen', {
		nameKey: 'PerformanceRegen',
		img: 'performanceregen',
		multiplier: 0.75,
		affectTotalMulti: true,
		conflictions: [],
		tier: 0
	});
	gauntletModsData.set('EasyChart', {
		nameKey: 'EasyChart',
		img: 'easychart',
		multiplier: 5.00,
		affectTotalMulti: true,
		conflictions: [],
		tier: 0
	});
	gauntletModsData.set('NoMechanics', {
		nameKey: 'NoMechanics',
		img: 'nomechanics',
		multiplier: 0.5,
		affectTotalMulti: true,
		conflictions: ['HarderMechanics', 'InstantKillMechanics'],
		tier: 0
	});
	gauntletModsData.set('BiggerJudgementWindows', {
		nameKey: 'BiggerJudgementWindows',
		img: 'biggerjudgementwindows',
		multiplier: 0.75,
		affectTotalMulti: true,
		conflictions: ['SmallerJudgementWindows'],
		tier: 0
	});
	gauntletModsData.set('ReducedScrollSpeed', {
		nameKey: 'ReducedScrollSpeed',
		img: 'reducedscrollspeed',
		multiplier: 2.0,
		affectTotalMulti: true,
		conflictions: [],
		tier: 0
	});
	gauntletModsData.set('OneSongSkip', {
		nameKey: 'OneSongSkip',
		img: 'onesongskip',
		multiplier: 0.5,
		affectTotalMulti: true,
		conflictions: [],
		tier: 0
	});
	gauntletModsData.set('IncreasedPerformanceLoss', {
		nameKey: 'IncreasedPerformanceLoss',
		img: 'increasedperformanceloss',
		multiplier: 0.5,
		affectTotalMulti: false,
		conflictions: [],
		tier: 1
	});
	gauntletModsData.set('SmallerJudgementWindows', {
		nameKey: 'SmallerJudgementWindows',
		img: 'smallerjudgementwindows',
		multiplier: 0.5,
		affectTotalMulti: false,
		conflictions: ['BiggerJudgementWindows'],
		tier: 1
	});
	gauntletModsData.set('ComboCountRequirement', {
		nameKey: 'ComboCountRequirement',
		img: 'combocountrequirement',
		multiplier: 0.75,
		affectTotalMulti: false,
		conflictions: [],
		tier: 1
	});
	gauntletModsData.set('OpponentPerformanceDrain', {
		nameKey: 'OpponentPerformanceDrain',
		img: 'opponentperformancedrain',
		multiplier: 0.75,
		affectTotalMulti: false,
		conflictions: [],
		tier: 1
	});
	gauntletModsData.set('RandomNoteColors', {
		nameKey: 'RandomNoteColors',
		img: 'randomnotecolors',
		multiplier: 0.25,
		affectTotalMulti: false,
		conflictions: [],
		tier: 1
	});
	gauntletModsData.set('SixKeyCharts', {
		nameKey: 'SixKeyCharts',
		img: 'sixkeycharts',
		multiplier: 0.01,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('HarderMechanics', {
		nameKey: 'HarderMechanics',
		img: 'hardermechanics',
		multiplier: 1.5,
		affectTotalMulti: false,
		conflictions: ['NoMechanics'],
		bonusPair: 'InstantKillMechanics',
		tier: 2
	});
	gauntletModsData.set('InstantKillMechanics', {
		nameKey: 'InstantKillMechanics',
		img: 'instantkillmechanics',
		multiplier: 1.5,
		affectTotalMulti: false,
		conflictions: ['NoMechanics'],
		bonusPair: 'HarderMechanics',
		tier: 2
	});
	gauntletModsData.set('HigherScoreRequirement', {
		nameKey: 'HigherScoreRequirement',
		img: 'higherscorerequirement',
		multiplier: 1.0,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('StealthNotes', {
		nameKey: 'StealthNotes',
		img: 'stealthnotes',
		multiplier: 0.75,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('ZoomingNotes', {
		nameKey: 'ZoomingNotes',
		img: 'zoomingnotes',
		multiplier: 0.75,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('OpponentSwap', {
		nameKey: 'OpponentSwap',
		img: 'opponentswap',
		multiplier: 0.01,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('ReleaseOnHoldEnds', {
		nameKey: 'ReleaseOnHoldEnds',
		img: 'releaseonholdends',
		multiplier: 0.01,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('OneLife', {
		nameKey: 'OneLife',
		img: 'onelife',
		multiplier: 1.0,
		affectTotalMulti: false,
		conflictions: [],
		tier: 2
	});
	gauntletModsData.set('DivineOrHigher', {
		nameKey: 'DivineOrHigher',
		img: 'divineorhigher',
		multiplier: 0.01,
		affectTotalMulti: false,
		conflictions: [],
		tier: 3
	});
	gauntletModsData.set('PermaDamage', {
		nameKey: 'PermaDamage',
		img: 'permadamage',
		multiplier: 0.0,
		affectTotalMulti: false,
		conflictions: [],
		tier: 3
	});
	gauntletModsData.set('IncreasedSongSpeed', {
		nameKey: 'IncreasedSongSpeed',
		img: 'increasedsongspeed',
		multiplier: 1.5,
		affectTotalMulti: false,
		conflictions: [],
		tier: 3
	});
	gauntletModsData.set('ShuffledNoteReceptors', {
		nameKey: 'ShuffledNoteReceptors',
		img: 'shufflednotereceptors',
		multiplier: 1.25,
		affectTotalMulti: false,
		conflictions: [],
		tier: 3
	});
}

// Gauntlet Variables
public static var curGauntletMultiplier:Float = 1.0;
public static var gauntletBackgroundThresholds:Array<Float> = [4, 8];
public static var curGauntletMods:Array = [];
public static var curGauntletGamemode:String = 'Standard';
public static var requiredComboCount:Int = 0;
public static var curMods:Dynamic;
