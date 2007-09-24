/**
 * MFPlayerEvent.as
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

package MythFlash.Events
{
        import flash.events.Event;

        public class MFPlayerEvent extends Event
        {
    
            // Define static constant,
            public static const STYLES_LOADED:String = "stylesLoaded";
            public static const FULL_SCREEN:String = "fullScreen";
            
            // Public constructor. 
            public function MFPlayerEvent(type:String,isEnabled:Boolean=false)
            {
                // Call the constructor of the superclass.
                super(type);
                
                // Set the new property.
                this.isEnabled = isEnabled;
            }

            // Define a public variable to hold the state of the enable property.
            public var isEnabled:Boolean;

            // Override the inherited clone() method. 
            override public function clone():Event
            {
                return new MFPlayerEvent(type, isEnabled);
            }
    }
}