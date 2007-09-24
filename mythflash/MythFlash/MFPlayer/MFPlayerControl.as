/**
 * MFPlayerControl.as
 * 
 * Copyright (C) 2007 Jean-Philippe Steinmetz
 *
 * This file is part of MythFlash.
 * 
 * MythFlash is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * MythFlash is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with MythFlash; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 **/

package MythFlash.MFPlayer
{
	import mx.core.UIComponent;
	
	import mx.controls.VideoDisplay;
	
	import mx.containers.HBox;
	import mx.containers.VBox;
	import mx.controls.Button;
	import mx.controls.HSlider;
	import mx.controls.VSlider;
	import mx.controls.ProgressBar;
	import mx.controls.Label;
	
	import flash.events.Event;
	import flash.utils.Timer;
	import mx.effects.Fade;
	import mx.events.EffectEvent;
	
	public class MFPlayerControl extends UIComponent
	{
		private var _source:VideoDisplay;
		
		// UI Components
		private var boundingBox:HBox;
		protected var playBtn:Button;
		protected var pauseBtn:Button;
		protected var stopBtn:Button;
		
		protected var fullScreenBtn:Button;
		
		protected var volMenuBtn:Button;
		protected var volumeSlider:VSlider;
		protected var volSliderBox:VBox;
		private var volSliderTimer:Timer;
		
		protected var progressBar:ProgressBar;
		protected var progressSlider:HSlider;
		protected var seeking:Boolean;
		private var _totalTime:Number;
		
		protected var timeLabel:Label;
		
		// Dispatch Events
		[Bindable(event="toggleFullscreen")]
		
		function MFPlayerControl(source:VideoDisplay)
		{
			_source = source;
		}
		
		override public function initialize():void
		{
			super.initialize();
			
			volSliderTimer = new Timer(3000, 1);
			volSliderTimer.addEventListener("timer",hideVolume);
			
			_source.addEventListener("ready",videoReady);
			_source.addEventListener("complete",videoComplete);
			
			seeking = false;
			_totalTime = 0;
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			if(!boundingBox)
			{
				boundingBox = new HBox();
				boundingBox.styleName = "mfpControlBBox";
				addChild(boundingBox);
			}
			
			if(!fullScreenBtn)
			{
				fullScreenBtn = new Button();
				//fullScreenBtn.toolTip = "Toggle full screen mode";
				fullScreenBtn.styleName = "mfpFullScreenBtn";
				fullScreenBtn.addEventListener("click",toggleFullscreen);
				boundingBox.addChild(fullScreenBtn);
			}
			
			if(!playBtn)
			{
				playBtn = new Button();
				//playBtn.toolTip = "Play";
				playBtn.styleName = "mfpPlayBtn";
				playBtn.addEventListener("click",play);
				addChild(playBtn);
			}
			
			if(!pauseBtn)
			{
				pauseBtn = new Button();
				//pauseBtn.toolTip = "Pause";
				pauseBtn.styleName = "mfpPauseBtn";
				pauseBtn.addEventListener("click",pause);
				addChild(pauseBtn);
			}
			
			if(!stopBtn)
			{
				stopBtn = new Button();
				//stopBtn.toolTip = "Stop";
				stopBtn.styleName = "mfpStopBtn";
				stopBtn.addEventListener("click",stop);
				addChild(stopBtn);
			}
			
			if(!progressBar)
			{
				progressBar = new ProgressBar();
				progressBar.height = 10;
				progressBar.labelPlacement = "center";
				progressBar.label = "";
				//progressBar.styleName = "mfpProgressBar";
				addChild(progressBar);
			}
			
			if(!progressSlider)
			{
				progressSlider = new HSlider();
				progressSlider.setStyle("dataTipPlacement","top");
				progressSlider.height = 20;
				progressSlider.snapInterval = 0.01;
				
				progressSlider.addEventListener("thumbPress",
												function(event:Event):void { seeking = true; });
				progressSlider.addEventListener("thumbRelease",
												function(event:Event):void { seeking = false; });
				progressSlider.addEventListener("change", seekTo);
				progressSlider.styleName = "mfpProgressSlider";
				addChild(progressSlider);
			}
			
			if(!timeLabel)
			{
				timeLabel = new Label();
				timeLabel.text = playTimeToString(0);
				timeLabel.styleName = "mfpTimeLabel";
				addChild(timeLabel);
			}
			
			if(!volMenuBtn)
			{
				volMenuBtn = new Button();
				//volMenuBtn.toolTip = "Volume";
				volMenuBtn.addEventListener("click",toggleVolumeMenu);
				volMenuBtn.styleName = "mfpVolumeBtn";
				addChild(volMenuBtn);
			}
			
			if(!volSliderBox)
			{
				volSliderBox = new VBox();
				volSliderBox.styleName = "mfpVolumeSliderBox";
				addChild(volSliderBox);
				
				volSliderBox.visible = false;
			}
			
			if(!volumeSlider)
			{
				volumeSlider = new VSlider();
				volumeSlider.value = _source.volume*100;
				volumeSlider.minimum = 0;
				volumeSlider.maximum = 100;
				volumeSlider.snapInterval = 1;
				volumeSlider.setStyle("dataTipPlacement","left");
				volumeSlider.addEventListener("change",adjustVolume);
				volumeSlider.addEventListener("mouseDownOutside",hideVolume);
				volumeSlider.styleName = "mfpVolumeSlider";
				volSliderBox.addChild(volumeSlider);
			}
			
			invalidateDisplayList();
		}
		
		override protected function measure():void
		{
			super.measure();
			
			measuredWidth = 320;
			measuredHeight = 20;
			
			measuredMinWidth = 320;
			measuredMinHeight = 20;
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);

			boundingBox.width = width;
			boundingBox.height = height;
			
			fullScreenBtn.width = 30;
			fullScreenBtn.height = height-4;
			fullScreenBtn.x = 2;
			fullScreenBtn.y = 2;
			
			playBtn.width = 25;
			playBtn.height = height-4;
			playBtn.x = fullScreenBtn.x+fullScreenBtn.width+5;
			playBtn.y = 2;
			
			pauseBtn.width = 25;
			pauseBtn.height = height-4;
			pauseBtn.x = fullScreenBtn.x+fullScreenBtn.width+5;
			pauseBtn.y = 2;
			
			stopBtn.width = 25;
			stopBtn.height = height-4;
			stopBtn.x = playBtn.x+playBtn.width+5;
			stopBtn.y = 2;
			
			volMenuBtn.width = 30;
			volMenuBtn.height = height-4;
			volMenuBtn.x = width - volMenuBtn.width - 2;
			volMenuBtn.y = 2;
			
			timeLabel.width = timeLabel.text.length*8;
			timeLabel.height = height-2;
			timeLabel.x = volMenuBtn.x-timeLabel.width-3;
			timeLabel.y = 2;
			
			progressBar.width = (timeLabel.x-3) - (stopBtn.x+stopBtn.width+5);
			progressBar.height = height*0.60;
			progressBar.x = stopBtn.x+stopBtn.width+5;
			progressBar.y = (height/2) - (progressBar.height/2);
			progressBar.source = _source;
			
			progressSlider.width = progressBar.width;
			progressSlider.height = height-4;
			progressSlider.x = progressBar.x;
			progressSlider.y = (height/2) - (progressSlider.height/2);
			
			volSliderBox.width = 22;
			volSliderBox.height = 75;
			volSliderBox.setStyle("padding", 2);
			volSliderBox.x = volMenuBtn.x+(volMenuBtn.width/2)-(volSliderBox.width/2);
			volSliderBox.y = volMenuBtn.y-volSliderBox.height-2;
			
			volumeSlider.height = 75;
			
			if(_source.playing)
			{
				playBtn.visible = false;
				pauseBtn.visible = true;
			}
			else
			{
				playBtn.visible = true;
				pauseBtn.visible = false;
			}
		}
		
		public function get source():VideoDisplay
		{
			return _source;
		}
		
		[Inspectable(defaultValue="")]
		public function set source(video:VideoDisplay):void
		{
			_source = video;
		}
		
		public function get totalTime():Number
		{
			return _totalTime;
		}
		
		public function set totalTime(value:Number):void
		{
			if(value >= 0) _totalTime = value;
		}
		
		public function play(event:Event):void
		{
			_source.play();
			
			invalidateDisplayList();
		}
		
		public function pause(event:Event):void
		{
			_source.pause();
			
			invalidateDisplayList();
		}
		
		public function stop(event:Event = null):void
		{
			_source.stop();
			
			invalidateDisplayList();
		}
		
		private function videoReady(event:Event):void
		{
			if(_source.totalTime == 0) progressSlider.maximum = _totalTime;
			else progressSlider.maximum = _source.totalTime;
				
			_source.addEventListener("playheadUpdate",playheadUpdate);
			timeLabel.text = playTimeToString(_source.totalTime);
			
			invalidateDisplayList();
		}
		
		private function videoComplete(event:Event):void
		{
			if(_totalTime > _source.playheadTime) _totalTime = _source.playheadTime;
			
			_source.totalTime = _totalTime;
		}
		
		private function playheadUpdate(event:Event):void
		{
			if(!seeking)
			{
				if(_source.totalTime == 0) progressSlider.maximum = _totalTime;
				
				progressSlider.value = _source.playheadTime;
			}
			
			if(_source.playheadTime > _totalTime) _totalTime = _source.playheadTime;
			
			timeLabel.text = playTimeToString(_source.playheadTime);
			
			invalidateDisplayList();
		}
		
		private function seekTo(event:Event):void
		{
			if(Math.abs(_source.playheadTime-progressSlider.value) > 1)
			{
				_source.playheadTime = progressSlider.value;
				
				timeLabel.text = playTimeToString(_source.playheadTime);
				
				invalidateDisplayList();
			}
		}
		
		private function toggleVolumeMenu(event:Event):void
		{
			if(!volSliderBox.visible)
			{
				volSliderBox.visible = true;
				volSliderBox.alpha = 100;
				volSliderTimer.start();
			}
			else
			{
				var hideAnim:Fade = new Fade();
				hideAnim.target = volSliderBox;
				hideAnim.alphaFrom = 100;
				hideAnim.alphaTo = 0;
				hideAnim.duration = 2000;
				hideAnim.addEventListener(EffectEvent.EFFECT_END,
						function(evt:Event):void { volSliderBox.visible = false; });
				hideAnim.play();
			}
		}
		
		private function adjustVolume(event:Event):void
		{
			_source.volume = volumeSlider.value/100;
			volSliderTimer.reset();
			volSliderTimer.start();
		}
		
		private function hideVolume(event:Event):void
		{
			volSliderBox.visible = false;
		}
		
		private function toggleFullscreen(event:Event):void
		{
			dispatchEvent(new Event("toggleFullscreen"));
		}
		
		private function playTimeToString(value:Number):String
		{
			var hrs:String;
			var min:String;
			var sec:String;
			
			value = Math.floor(value); // make sure value is only seconds
			
			sec = new String(value%60);
			if(sec.length < 2) sec = "0"+sec;
			value = Math.floor(value/60);
			
			min = new String(value%60);
			if(min.length < 2) min = "0"+min;
			value = Math.floor(value/60);
			
			if(value > 9) hrs = new String(value);
			else hrs = "0"+value;
			
			if(value > 0) return hrs+":"+min+":"+sec;
			else return min+":"+sec;
		}
	}
}