/**
 * MFPStill.as
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
	import flash.display.Sprite;
	import mx.controls.Image;
	import mx.controls.Label;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	/**
	 * A component for displaying an image with a black background and a text label over top.
	 * Typically this is used as a button that will create/start a MFPlayer component.
	 **/
	public class MFPStill extends UIComponent
	{
		protected var background:Sprite;
		protected var image:Image;
		protected var labelTxt:Label;
		
		// Dispatchs events
		[Bindable(event="click")]
		
		function MFPStill()
		{
		}
		
		/**
		 * Sets up the internal structure of the component
		 **/
		override public function initialize():void
		{
			super.initialize();
		}
		
		/**
		 * Creates all child objects required for the component
		 **/
		override protected function createChildren():void
		{
			super.createChildren();
			
			if(!background)
			{
				background = new Sprite();
				addChild(background);
			}
			
			if(!image)
			{
				image = new Image();
				image.maintainAspectRatio = true;
				image.autoLoad = true;
				addChild(image);
				
				image.addEventListener(Event.COMPLETE,function(event:Event):void { invalidateDisplayList(); });
			}
			
			if(!labelTxt)
			{
				labelTxt = new Label();
				labelTxt.width = 100;
				labelTxt.height = 25;
				labelTxt.setStyle("fontFamily","Verdana");
				labelTxt.setStyle("fontSize",16);
				labelTxt.setStyle("backgroundStyle","solid");
				labelTxt.setStyle("backgroundColor",0x444444);
				labelTxt.setStyle("color",0xffffff);
				labelTxt.alpha = 75;
				labelTxt.selectable = false;
				//addChild(labelTxt);
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
			
			measuredMinWidth = 100;
			measuredMinHeight = 100;
		}
		
		/**
		 * Draws the objects and/or sizes and positions its children.
		 **/
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			background.graphics.beginFill(0x000000,1.0);
			background.graphics.drawRect(0,0,width,height-20);
			background.graphics.endFill();
			background.graphics.beginFill(0x000000,0.0);
			background.graphics.drawRect(0,height-20,width,height);
			background.graphics.endFill();
			
			if(image.content)
			{
				image.width = image.content.width;
				image.height = image.content.height;
				
				if(image.height == height) image.height -= 20;
			}
			else
			{
				image.width = width;
				image.height = height-20;
			}
			image.x = (width/2) - (image.width/2);
			image.y = (height/2) - (image.height/2) - ((height-image.height)/2);
			
			//labelTxt.width = 100;
			//labelTxt.height = 25;
			//labelTxt.x = (width/2) - (labelTxt.width/2);
			//labelTxt.y = (height/2) - (labelTxt.height/2);
		}
		
		/**
		 * Gets or sets the image file to be displayed
		 **/
		public function get source():String
		{
			return new String(image.source);
		}
		
		/**
		 * Gets or sets the image file to be displayed
		 **/
		[Inspectable(defaultValue="")]
		public function set source(value:String):void
		{
			if(value && value != "") image.source = value;
			
			invalidateDisplayList();
		}
		
		/**
		 * Gets or sets the label to be displayed over the image
		 **/
		public function get label():String
		{
			return labelTxt.text;
		}
		
		/**
		 * Gets or sets the label to be displayed over the image
		 **/
		[Inspectable(defaultValue="Click to play.")]
		public function set label(value:String):void
		{
			//if(value && value != "") labelTxt.text = value;
			
			invalidateDisplayList();
		}
	}
}