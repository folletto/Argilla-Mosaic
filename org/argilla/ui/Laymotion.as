/*
 * Argilla UI Motion Layer
 * version 0.1
 *
 * last revision: 2007 11 25
 *
 * Copyright (C) 2007 Davide Casali. All Rights Reserved.
 * Released under GNU LGPL 2.1.
 * 
 * by Davide 'Folletto' Casali <folletto AT gmail DOT com>
 *
 */

/*
 * Extended DisplayContainer to animate addChild() and removeChild() methods.
 * 
 * To add custom animations simply attach the animation function to:
 *   Laymotion.addAnimation = ...
 *   Laymotion.removeAnimation = ...
 * Or use the constructor:
 *   var lay = new Laymotion(addAnimationFunction, removeAnimationFunction);
 * 
 * The animation functions are defined like:
 *   function addAnimationMock(child:DisplayObject, completeFunction:Function) { ... }
 * You *have* to call the completeFunction() inside your animation function in order
 * to trigger the completion event (TweenEvent.MOTION_COMPLETE).
 * 
 * Note that the added/removed children will receive a TweenEvent.MOTION_COMPLETE too.
 *   
 */

package org.argilla.ui {
	
	import flash.display.*;
	
	import fl.transitions.Tween;
	import fl.transitions.TweenEvent;
	import fl.transitions.easing.Regular;
	
	public dynamic class Laymotion extends Sprite {
		
		// \/ ANIMATION
		private var duration:Number = 0.8; // duration
		private var addAnimation:Function = null; // Add Animation function
		private var removeAnimation:Function = null; // Remove Animation function
		private var tweens:Array = []; // array of tweens used in the animations
		
		public function Laymotion(fxAdd:Function = null, fxRemove:Function = null) {
			/********************************************************************************
			 * CONSTRUCTOR
			 */
			this.addAnimation = fxAdd || this.addAnimationDefault;
			this.removeAnimation = fxRemove || this.removeAnimationDefault;
		}
		
		// \/ OVERRIDES
		public override function addChild(child:DisplayObject):DisplayObject {
			return this.addChildAt(child, super.numChildren);
		}
		
		public override function addChildAt(child:DisplayObject, index:int):DisplayObject {
			/********************************************************************************
			 * Wraps te normal addChild() and adds animation behaviour.
			 */
			child.visible = false; // Avoids flickering on animation start
			super.addChildAt(child, index);
			this.addAnimation(child, function() {
				child.dispatchEvent(new TweenEvent(TweenEvent.MOTION_FINISH, +1 /*time*/, 1.0 /*val*/));
			});
			
			return child;
		}
		
		public override function removeChild(child:DisplayObject):DisplayObject {
			/********************************************************************************
			 * Wraps te normal removeChild() and adds animation behaviour.
			 */
			var super_removeChild = super.removeChild; /* super is a language expression */
			
			this.removeAnimation(child, function() {
				super_removeChild(child);
				child.dispatchEvent(new TweenEvent(TweenEvent.MOTION_FINISH, -1 /*time*/, 1.0 /*val*/));
			});
			
			return child;
		}
		
		public override function removeChildAt(index:int):DisplayObject {
			return this.removeChild(super.getChildAt(index));
		}
		
		// \/ ANIMATIONS
		public function addAnimationDefault(child:DisplayObject, completeFx:Function) {
			/********************************************************************************
			 * Default Add animation function.
			 */
			var originalAlpha = child.alpha;
			child.alpha = 0.0;
			child.visible = true;
			
			var twAlpha:Tween = new Tween(child, "alpha", Regular.easeOut, 0.0, originalAlpha, this.duration, true);
			twAlpha.addEventListener(TweenEvent.MOTION_FINISH, function(event:TweenEvent) {
				completeFx();
			});
		}
		
		public function removeAnimationDefault(child:DisplayObject, completeFx:Function) {
			/********************************************************************************
			 * Default Remove animation function.
			 */
			var twAlpha:Tween = new Tween(child, "alpha", Regular.easeOut, child.alpha, 0.0, this.duration, true);
			twAlpha.addEventListener(TweenEvent.MOTION_FINISH, function(event:TweenEvent) {
				completeFx();
			});
		}
		
	}
}