/**
 * MFPlayer.as
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
	
	import flash.display.Stage;
	import flash.display.StageDisplayState;
	
	import mx.controls.VideoDisplay;
	import MythFlash.MFPlayer.MFPlayerControl;
	
	import flash.events.Event;
	import flash.events.FullScreenEvent;
	import flash.events.MouseEvent;
	import mx.events.EffectEvent;
	import MythFlash.Events.MFPlayerEvent;
	import flash.utils.Timer;
	import mx.styles.StyleManager;
	import flash.ui.Mouse;
	import mx.effects.Fade;
	
	/**
	 * The MFPlayer component allows you to play an FLV file or stream in a Flex/Flash application. This component allows you to reassign the controls and supports full screen mode.
	 **/
	[Event(name=MFPlayerEvent.FULL_SCREEN, type="MythFlash.MFPlayerEvent")]
	[Event(name=MFPlayerEvent.STYLES_LOADED, type="MythFlash.MFPlayerEvent")]
	public class MFPlayer extends UIComponent
	{
		private var origX:uint;
		private var origY:uint;
		private var origWidth:uint;
		private var origHeight:uint;
		private var fullscreen:Boolean;
		private var controllerTimer:Timer;
		private var _styles:String;
		
		// UI Components
		protected var video:VideoDisplay;
		
		protected var videoController:MFPlayerControl;
		private var vcOrigAlpha:Number;
		
		// Animation Effects
		
		
		/**
		 * Default constructor
		 **/
		function MFPlayer()
		{
		}
		
		/**
		 * Initializes the internal structure of the component
		 **/
		override public function initialize():void
		{
			super.initialize();
			
			controllerTimer = new Timer(3000,1);
			controllerTimer.addEventListener("timer",hideController);
			
			//StyleManager.loadStyleDeclarations("MFPlayer_styles.swf");
			
			addEventListener("addedToStage",addedToStage);
		}
		
		/**
		 * Creates all child objects required for the component
		 **/
		override protected function createChildren():void
		{
			super.createChildren();
			
			if(!video)
			{
				video = new VideoDisplay();
				video.autoPlay = false;
				video.maintainAspectRatio = true;
				addChild(video);
				
				video.addEventListener(MouseEvent.CLICK,togglePlayPause);
			}
			
			if(!videoController)
			{
				videoController = new MFPlayerControl(video);
				videoController.addEventListener("toggleFullscreen",toggleFullScreen);
				vcOrigAlpha = videoController.alpha;
				addChild(videoController);
			}
			
			invalidateDisplayList();
		}
		
		/**
		 * Calculates the default size as well as the minimum size required for the component.
		 **/
		override protected function measure():void
		{
			super.measure();
			
			measuredWidth = 320;
			measuredHeight = 260;
			
			measuredMinWidth = 320;
			measuredMinHeight = 260;
		}
		
		/**
		 * Draws the objects and/or sizes and positions its children.
		 **/
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			if(fullscreen && stage != null)
			{	
				video.x = video.y = 0;
				video.width = this.width;
				video.height = this.height;
				
				videoController.width = video.width;
				videoController.height = 20;
				videoController.x = video.x;
				videoController.y = video.y+video.height-videoController.height;
			}
			else
			{
				video.x = video.y = 0;
				video.width = this.width;
				video.height = this.height-videoController.height;
				
				videoController.width = video.width;
				videoController.height = 20;
				videoController.x = video.x;
				videoController.y = video.y+video.height;
			}
			
			videoController.invalidateDisplayList();
		}
		
		/**
		 * This function is called when an addedToStage event is dispatched from the stage object.
		 * @param event The event object corresponding to the dispatcher
		 **/
		private function addedToStage(event:Event):void
		{
			if(origX == 0) origX = x;
			if(origY == 0) origY = y;
			if(origWidth == 0) origWidth = width;
			if(origHeight == 0) origHeight = height;
			
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, fullScreenRedraw);
		}
		
		/**
		 * Gets or sets the path of the FLV or stream to be played
		 **/
		public function get source():String
		{
			return video.source;
		}
		
		/**
		 * Gets or sets the path of the FLV or stream to be played
		 **/
		public function set source(value:String):void
		{
			if(value != null && value != "") video.source = value;
		}
		
		/**
		 * Gets or sets the total time for the FLV. This is used when the FLV file does not contain
		 * its own length information.
		 **/
		public function get totalTime():Number
		{
			return videoController.totalTime;
		}
		
		/**
		 * Gets or sets the total time for the FLV. This is used when the FLV file does not contain
		 * its own length information.
		 **/
		public function set totalTime(value:Number):void
		{
			videoController.totalTime = value;
		}
		
		/**
		 * Gets or sets the flag that determines if the video should automatically play when loaded
		 **/
		public function get autoPlay():Boolean
		{
			return video.autoPlay;
		}
		
		/**
		 * Gets or sets the flag that determines if the video should automatically play when loaded
		 **/
		public function set autoPlay(value:Boolean):void
		{
			video.autoPlay = value;
		}
		
		/**
		 * Gets or sets the flag that tells the component if the source is a stream or a file
		 **/
		public function get isLive():Boolean
		{
			return video.live;
		}
		
		/**
		 * Gets or sets the flag that tells the component if the source is a stream or a file
		 **/
		public function set isLive(value:Boolean):void
		{
			video.live = value;
		}
		
		/**
		 * Gets or sets the location of the CSS styling file for the component
		 **/
		public function get styles():String
		{
			return _styles;
		}
		
		/**
		 * Gets or sets the location of the CSS styling file for the component
		 **/
		public function set styles(value:String):void
		{
			if(value == null || value == "") return;
			
			_styles = value;
			
			StyleManager.loadStyleDeclarations(value);
			
			dispatchEvent(new Event(MFPlayerEvent.STYLES_LOADED));
			
			invalidateDisplayList();
		}
		
		/**
		 * Begins playing the video source
		 **/
		public function play():void
		{
			video.play();
		}
		
		/**
		 * Pauses the video source at the current playing position
		 **/
		public function pause():void
		{
			video.pause();
		}
		
		/**
		 * Stops the video source from playing and returns to the beginning
		 **/
		public function stop():void
		{
			video.stop();
		}
		
		/**
		 * This is called when the VideoDisplay is clicked and will pause
		 * or play the current video.
		 * @param event The event object sent by the dispatcher
		 **/
		private function togglePlayPause(event:Event):void
		{
			if(video.playing) pause();
			else play();
		}
		
		/**
		 * This is called when the FullScreen button is pressed on the
		 * controller and switches the component to full screen mode
		 * @param event The event object sent by the dispatcher
		 **/
		private function toggleFullScreen(event:Event):void
		{
			
			if(stage.displayState == StageDisplayState.NORMAL)
			{
				this.stage.displayState = StageDisplayState.FULL_SCREEN;
			}
			else
			{
				this.stage.displayState = StageDisplayState.NORMAL;
			}
		}
		
		/**
		 * This is called when the application enters full screen mode. The
		 * function performs calculations to redraw the video and controls to
		 * take up the entire space of the screen or to resize back down to
		 * its original size.
		 * @param event The event object sent by the dispatcher
		 **/
		private function fullScreenRedraw(event:FullScreenEvent):void
		{
			if(event.fullScreen)
			{
				this.x = this.y = 0;
				this.width = stage.width;
				this.height = stage.height;
				
				controllerTimer.reset();
				controllerTimer.start();
				addEventListener(MouseEvent.MOUSE_MOVE, showController);
				
				fullscreen = true;
			}
			else
			{
				this.x = origX;
				this.y = origY;
				this.width = origWidth;
				this.height = origHeight;
				
				removeEventListener(MouseEvent.MOUSE_MOVE, showController);
				controllerTimer.stop();
				
				fullscreen = false;
			}
			
			invalidateSize();
			invalidateDisplayList();
		}
		
		/**
		 * This function is called when in full screen mode to show the controller
		 **/
		private function showController(event:Event):void
		{
			Mouse.show();
			
			videoController.visible = true;
			videoController.alpha = vcOrigAlpha;
			
			controllerTimer.reset();
			controllerTimer.start();
		}
		
		/**
		 * This function is called when in full screen mode and the user has been idle for
		 * a period of time.
		 **/
		private function hideController(event:Event):void
		{	
			var hideAnim:Fade = new Fade();
			hideAnim.target = videoController;
			hideAnim.alphaFrom = vcOrigAlpha;
			hideAnim.alphaTo = 0;
			hideAnim.duration = 2000;
			hideAnim.addEventListener(EffectEvent.EFFECT_END,
					function(evt:Event):void { videoController.visible = false;
						Mouse.hide(); });
			hideAnim.play();
		}
	}
}