/*
 * Mosaic UI Alignment Swissknife Container
 * version 0.5.3
 *
 * last revision: 2008 01 29
 *
 * Copyright (C) 2007 Davide Casali. All Rights Reserved.
 * Released under GNU LGPL 2.1.
 * 
 * by Davide 'Folletto' Casali <folletto AT gmail DOT com>
 *
 */

/*
 * Helper to provide modular alignment between objects.
 * Each object can be bound to just one other object. New binds will redefine the old one.
 * 
 * Usage:
 *   var a = new Mosaic();
 *   a.tile(Mosaic.BOTTOM_RIGHT, Mosaic.TOP_LEFT, sprite1, sprite2);
 * 
 * You can also add a chain of elements, using the same pair of parameters:
 *   a.tile(Mosaic.BOTTOM_RIGHT, Mosaic.BOTTOM_LEFT, sprite1, sprite2, sprite3, sprite4);
 * 
 * You can use the contract form:
 *   a.tile("br", "bl", sprite1, sprite2, sprite3, sprite4);
 * 
 * To remove:
 *   a.untile(sprite2);
 * 
 * If there are elements bound to the removed element, they will realign "falling"
 * in the place of the unbound element.
 *
 * Note that normal addChild() also works, but it's automatically done on tile():
 *   a.addChild(sprite1);
 * 
 * The Mosaic object supports also an Array-like structure, using this syntax:
 *   a.array.name(Mosaic.BOTTOM_RIGHT, Mosaic.TOP_LEFT);
 *   a.array.name.push(sprite1);
 *   obj = a.array.name.pop();
 *   obj = a.array.name.shift();
 *   a.array.name.unshift(sprite2);
 *   a.array.splice(2, 1, sprite3, sprite4);
 *
 *   a.array.name[2]; // Positional get (arrya index)
 *   a.array.name["item"]; // Name get (getChildByName shortcut)
 * 
 * The Mosaic object supports also a "fast" creation for Display Objects, using mold()
 *   var obj = Mosaic.mold(TextField, "name", { prop1: "data", onEvent: function(){}, ... })
 *   a.array.name.mold(
 *     [TextField, "name1", { prop1: "data", onEvent: function(){}, ... }],
 *     [TextField, "name2", { prop1: "data", onEvent: function(){}, ... }],
 *   );
 *
 */

package org.argilla.ui {
	
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	
	import fl.events.*;
	import fl.transitions.Tween;
	import fl.transitions.TweenEvent;
	import fl.transitions.easing.Regular;
	
	public dynamic class Mosaic extends Sprite {
		
		// Constants
		public static const TOP_LEFT = 'tl';
		public static const BOTTOM_LEFT = 'bl';
		public static const TOP_RIGHT = 'tr';
		public static const BOTTOM_RIGHT = 'br';
		
		// Data Dictionary Item:
		//   [DisplayObject]: { x: 0, y: 0, alignA: "tr", alignB: "tl", parent: ..., }
		private var pairs:Dictionary;
		private var _array:MosaicArrays;
		
		// Displacement
		private var _margin:Number;
		
		// Position
		private var _nwidth:Number = 0;
		private var _nheight:Number = 0;
		private var _pwidth:Number = 0;
		private var _pheight:Number = 0;
		
		// Animation
		public var duration:Number;
		private var tweens:Dictionary; // Array to hold tweens
		
		public function Mosaic(margin:Number = 0, duration:Number = 0.5) {
			/********************************************************************************
			 * CONSTRUCTOR
			 */
			this.pairs = new Dictionary(true);
			this._array = new MosaicArrays(this);
			this.tweens = new Dictionary(true);
			
			this._margin = margin;
			this.duration = duration;
		}
		
		// \/ INTERFACE
		public function tile(alignA:String, alignB:String, A:DisplayObject, B:DisplayObject, ...N) {
			/********************************************************************************
			 * Add a new alignment
			 */
			var out = -1;
			
			// ****** Add first pair
			out = this.addPair(alignA, alignB, A, B);
			
			// ****** Add following pairs, if any
			if (N.length) {
				var first = B;
				for each (var second in N) {
					this.addPair(alignA, alignB, first, second);
					first = second;
				}
			}
			
			// ****** Align
			this.align();
			
			return out;
		}
		
		public function untile(...args) {
			/********************************************************************************
			 * Remove a binding
			 */
			// ****** Get parameters
			var reflow:Boolean = true;
			var objs:Array = [];
			for each (var arg in args) {
				if (arg is Boolean) reflow = arg;
				else if (arg is DisplayObject) objs.push(arg);
			}
			
			for each (var obj in objs) {
				// ****** Reflow
				if (reflow) {
					for (var child in this.pairs) {
						if (this.pairs[child].parent === obj) {
							if (obj in this.pairs && this.pairs[obj].parent) {
								// *** Parent has metadata, reflow properties
								this.pairs[child].alignA = this.pairs[obj].alignA;
								this.pairs[child].alignB = this.pairs[obj].alignB;
								this.pairs[child].parent = this.pairs[obj].parent;
							} else {
								// *** Parent hasn't metadata, move to parent's position
								this.move(child, this.xOf(obj), this.yOf(obj));
								
								// *** Removed root Object
								this.pairs[child].parent = null;
							}
							break;
						}
					}
				}
				
				// ****** Remove Pair
				this.removePair(obj);				
			}
			
			if (reflow) {
				// ****** Reflow alignments
				this.align();
			}
		}
		
		public static function mold(clay:*, ...args) {
			/********************************************************************************
			 * Compact creation of objects.
			 * Syntax:
			 *   <Class>, [<name>], { ... }, { ... }
			 * - Class: can be a Class, a DisplayObject, a Function or a class name String.
			 * - name : is optional, will be set as the class name. Must be a String.
			 * - {}   : are enumerable Objects containing the properties to be set as keys 
			 *          and the matching values.
			 * EXAMPLE:
			 *   TextField, "name", { width: 200, height: 100, textColor: 0x555555, textSize: 12 }
			 * 
			 * The passed properties can be:
			 * - attribute names = values
			 * - events = functions, where "ADDED_TO_STAGE" will be written as "onAddedToStage"
			 * - styles = values, applied if an existing attribute doesn't exist
			 */
			var out = null;
			var klass:Class;
			
			// ****** Create
			if (clay is Class) {
				out = new clay();
				klass = clay;
			} else if (clay is DisplayObject) {
				out = clay;
				klass = (getDefinitionByName(getQualifiedClassName(clay)) as Class);
			} else if (clay is Function) {
				out = clay();
				klass = (getDefinitionByName(getQualifiedClassName(out)) as Class);
			} else if (clay is String) {
				out = new (getDefinitionByName(clay) as Class)()
				klass = (getDefinitionByName(clay) as Class);
			}
			
			if (out) {
				// ****** Args loop
				var propsArray:Array = [];
				for each (var arg in args) {
					if (arg is String) out.name = arg; // name
					else propsArray.push(arg); // properties
				}
				
				// ****** Defaults
				var props = null;
				while (props = propsArray.pop()) {
					if (!("embedFonts" in props) || props["embedFonts"] !== false) {
						if ("embedFonts" in out) out.embedFonts = true;
						else if ("setStyle" in out) out.setStyle("embedFonts", true);
					}
					if (!("defaultTextFormat" in props || "textFormat" in props)) {
						// *** Get TextFormat
						var textformat:TextFormat;
						if ("defaultTextFormat" in out)textformat = out.defaultTextFormat;
						else if ("getStyle" in out) textformat = out.getStyle("textFormat");
						if (!textformat) textformat = new TextFormat();
						
						// *** Update TextFormat
						if ("textFont" in props) textformat.font = props["textFont"];
						else if (Font.enumerateFonts().length > 0) textformat.font = Font.enumerateFonts()[0].fontName;
						if ("textSize" in props) textformat.size = props["textSize"];
						if ("textColor" in props) textformat.color = props["textColor"];
						if ("textAlign" in props) textformat.align = props["textAlign"];
						if ("textBold" in props) textformat.bold = props["textBold"];
						if ("textItalic" in props) textformat.italic = props["textItalic"];
						if ("textUnderline" in props) textformat.underline = props["textUnderline"];
						if ("textLetterSpacing" in props) textformat.letterSpacing = props["textLetterSpacing"];
						
						// *** Set TextFormat
						if ("defaultTextFormat" in out) out.defaultTextFormat = textformat;
						else if ("setStyle" in out) out.setStyle("textFormat", textformat);
					}
					
					// ****** Apply
					for (var name in props) {
						// 0. Avoid wrong assignments
						if (!(name is String)) continue;
						else if (name == "textFont" || name == "textSize" || name == "textColor" || name == "textAlign" || name == "textBold" || name == "textItalic" || name == "textUnderline" || name == "textLetterSpacing") continue;
						// I. Property, declared
						else if (name in out) out[name] = props[name];
						// II. Events
						else if (name.substr(0, 2) == "on") {
							var type = name.replace(/([A-Z]+)/g, "_$1").substr(3).toUpperCase(); // onEventName to EVENT_NAME
							if (type in Event) out.addEventListener(Event[type], props[name]);
							else if (type in MouseEvent) out.addEventListener(MouseEvent[type], props[name]);
							else if (type in KeyboardEvent) out.addEventListener(KeyboardEvent[type], props[name]);
							else if (type in FocusEvent) out.addEventListener(FocusEvent[type], props[name]);
							else if (type in ListEvent) out.addEventListener(ListEvent[type], props[name]);
							else if (type in TextEvent) out.addEventListener(TextEvent[type], props[name]);
							else if (type in ScrollEvent) out.addEventListener(ScrollEvent[type], props[name]);
							else if (type in SliderEvent) out.addEventListener(SliderEvent[type], props[name]);
							else if (type in ComponentEvent) out.addEventListener(ComponentEvent[type], props[name]);
						}
						// III. Styles
						else if ("getStyleDefinition" in klass && name in klass["getStyleDefinition"]()) {
							out.setStyle(name, props[name]);
						}
						// IV. Property, any
						else out[name] = props[name];
					}
				}
			}
			
			return out;
		}
		
		public function align(obj:DisplayObject = null, done = null) {
			/********************************************************************************
			 * Recursive core alignment function.
			 */
			if (obj == null) {
				// ****** Recursion Start, first step
				done = []; // -Optimize
				this.updateSizeUsing(null);
				for (var i = 0; i < this.numChildren; i++) {
					if (this.getChildAt(i) in this.pairs) {
						this.align(this.getChildAt(i), done); // @ Recurse Start
					} else {
						this.updateSizeUsing(this.getChildAt(i)); // size evaluation (untiled pieces)
					}
				}
				// Mosaics Affinity
				if (this.parent is Mosaic) (this.parent as Mosaic).align();
			} else {
				// ****** Recursed
				if (this.pairs[obj].parent && done.indexOf(obj) < 0) {
					done.push(obj); // -Optimize
					if (this.pairs[obj].parent in this.pairs) {
						this.align(this.pairs[obj].parent, done); // @ Recurse UP
					}
					this.alignPair(this.pairs[obj].alignA, this.pairs[obj].alignB, this.pairs[obj].parent, obj); // Displace!
					
					this.updateSizeUsing(obj); // size evaluation
				}
			}
		}
		
		// \/ DISPLACEMENT
		private function alignPair(alignA:String, alignB:String, A:DisplayObject, B:DisplayObject) {
			/********************************************************************************
			 * Choose the right displacement and move().
			 */
			var x = this.xOf(A) + this.pairs[B].marginLeft;
			var y = this.yOf(A) + this.pairs[B].marginTop;
			
			// ****** Eval A (parent) corner position
			switch (alignA) {
				case TOP_LEFT:
					x -= this._margin;
					y -= this._margin;
					break;
				case TOP_RIGHT:
					x += this._margin + this.widthOf(A);
					y -= this._margin;
					break;
				case BOTTOM_LEFT:
					x -= this._margin;
					y += this._margin + this.heightOf(A);
					break;
				case BOTTOM_RIGHT:
					x += this._margin + this.widthOf(A);
					y += this._margin + this.heightOf(A);
					break;
			}
			
			// ****** Eval B (child) corner position
			switch (alignB) {
				case TOP_LEFT:
					x += this._margin;
					y += this._margin;
					break;
				case TOP_RIGHT:
					x -= this._margin + this.widthOf(B);
					y += this._margin;
					break;
				case BOTTOM_LEFT:
					x += this._margin;
					y -= this._margin + this.heightOf(B);
					break;
				case BOTTOM_RIGHT:
					x -= this._margin + this.widthOf(B);
					y -= this._margin + this.heightOf(B);
					break;
			}
			
			// ****** Move
			this.move(B, x, y);
		}
		
		private function move(obj:DisplayObject, x:Number, y:Number) {
			/********************************************************************************
			 * Move the element w/ or w/o tween.
			 */
			// ****** Store
			// this is required to have the correct evaluation for tweened animations
			if (obj in this.pairs) {
				this.pairs[obj].x = x;
				this.pairs[obj].y = y;
			}
			
			if (this.duration > 0.05 && obj.visible == true) {
				// ****** Tweening
				delete this.tweens[obj]; // clean
				this.tweens[obj] = {
					x: new Tween(obj, "x", Regular.easeOut, obj.x, x, this.duration, true),
					y: new Tween(obj, "y", Regular.easeOut, obj.y, y, this.duration, true)
				}
				
				// *** Precise positioning at the end
				var self = this;
				this.tweens[obj].x.addEventListener(TweenEvent.MOTION_FINISH, function(event:TweenEvent) {
					obj.x = x;
					delete self.tweens[obj];
				});
				this.tweens[obj].y.addEventListener(TweenEvent.MOTION_FINISH, function(event:TweenEvent) {
					obj.y = y;
					delete self.tweens[obj];
				});
			} else {
				// ****** Static Move
				obj.x = x;
				obj.y = y;
			}
		}
		
		// \/ PAIRS DATA
		private function addPair(alignA:String, alignB:String, A:DisplayObject, B:DisplayObject):int {
			/********************************************************************************
			 * Add a pair of items to the Dictionary.
			 */
			// ****** Add Child
			if (!this.contains(A)) super.addChild(A);
			if (!this.contains(B)) super.addChild(B);
			
			// ****** Fill Dictionary
			this.pairs[B] = {
				x: this.xOf(B),
				y: this.yOf(B),
				marginLeft: B.x,
				marginTop: B.y,
				alignA: alignA,
				alignB: alignB,
				parent: A
			};
			
			// ****** Return
			return this.pairs.length - 1; // Index
		}
		
		private function removePair(obj:DisplayObject) {
			/********************************************************************************
			 * Remove an item from the Dictionary.
			 */
			if (this.contains(obj)) super.removeChild(obj);
			delete this.pairs[obj];
		}
		
		// \/ SIZES
		public function xOf(obj:DisplayObject):Number {
			/********************************************************************************
			 * Get the 'final' y of the passed DisplayObject.
			 * Useful to get the real x even during tweens.
			 */
			if (obj in this.pairs) {
				return this.pairs[obj].x;
			} else {
				return obj.x;
			}
		}
		
		public function yOf(obj:DisplayObject):Number {
			/********************************************************************************
			 * Get the 'final' y of the passed DisplayObject.
			 * Useful to get the real y even during tweens.
			 */
			if (obj in this.pairs) {
				return this.pairs[obj].y;
			} else {
				return obj.y;
			}
		}
		
		public function heightOf(obj:DisplayObject):Number {
			/********************************************************************************
			 * Get the 'real' height of the passed DisplayObject.
			 * Useful to handle bugged components that returns wrong size.
			 */
			if ('mosaicRect' in obj) {
				return obj['mosaicRect'].height;
			} else if (obj.scrollRect) {
				return obj.scrollRect.height;
			} else {
				return obj.height;
			}
		}
		
		public function widthOf(obj:DisplayObject):Number {
			/********************************************************************************
			 * Get the 'real' width of the passed DisplayObject.
			 * Useful to handle bugged components that returns wrong size.
			 */
			if ('mosaicRect' in obj) {
				return obj['mosaicRect'].width;
			} else if (obj.scrollRect) {
				return obj.scrollRect.width;
			} else {
				return obj.width;
			}
		}
		
		private function updateSizeUsing(obj:*) {
			/********************************************************************************
			 * Updates the current size using the passed object.
			 * It uses two references: negative values (n) and positive values (p).
			 * The negative values are required for object positioned before the origin.
			 * Those two values will be used to determine the real width and height.
			 */
			if (obj == null) {
				// ****** Reset
				this._pwidth = 0;
				this._pheight = 0;
				this._nwidth = 0;
				this._nheight = 0;
			} else {
				// ****** Update
				if (this._pwidth < this.xOf(obj) + this.widthOf(obj)) this._pwidth = this.xOf(obj) + this.widthOf(obj);
				if (this._pheight < this.yOf(obj) + this.heightOf(obj)) this._pheight = this.yOf(obj) + this.heightOf(obj);
				if (this._nwidth > this.xOf(obj)) this._nwidth = this.xOf(obj);
				if (this._nheight > this.yOf(obj)) this._nheight = this.yOf(obj);
			}
		}
		
		// \/ OVERRIDES
		override public function get width():Number {
			return this._pwidth - this._nwidth;
		}
		
		override public function get height():Number {
			return this._pheight - this._nheight;
		}
		
		override public function removeChild(child:DisplayObject):DisplayObject {
			/********************************************************************************
			 * Remove a children from the Mosaic
			 */
			var obj = super.removeChild(child);
			this.untile(obj, false);
			return obj;
		}
		
		override public function removeChildAt(index:int):DisplayObject {
			/********************************************************************************
			 * Remove a children from the Mosaic, by index
			 */
			var obj = super.removeChildAt(index);
			this.untile(obj, false);
			return obj;
		}
		
		override public function addChildAt(child:DisplayObject, index:int):DisplayObject {
			/********************************************************************************
			 * Add a child to the Mosaic container at a specified position.
			 */
			this.updateSizeUsing(child); // size evaluation
			return super.addChildAt(child, index);
		}
		
		override public function addChild(child:DisplayObject):DisplayObject {
			/********************************************************************************
			 * Add a child to the Mosaic container.
			 */
			this.updateSizeUsing(child); // size evaluation
			return super.addChild(child);
		}
		
		// \/ PROPERTIES
		public function get array():MosaicArrays {
			return this._array;
		}
		
		public function get margin():Number {
			return this._margin;
		}
		public function set margin(margin:Number) {
			this._margin = margin;
			this.align();
		}
	}
}

{
	import argilla.ui.Mosaic;

	class MosaicArrays extends flash.utils.Proxy {
		
		private var _mosaic:Mosaic = null;
		
		// Mosaic Arrays Items
		//   name: [MosaicArray]
		private var _arrays = {};
		
		// Assistive data
		private var _length:uint;
		
		public function MosaicArrays(mosaic:Mosaic) {
			/********************************************************************************
			 * CONSTRUCTOR
			 */
			this._mosaic = mosaic;
			this._length = 0;
			
			// Preconfigure two basic arrays, horizontal and vertical
			this['x'](Mosaic.TOP_RIGHT, Mosaic.TOP_LEFT);
			this['y'](Mosaic.BOTTOM_LEFT, Mosaic.TOP_LEFT);
		}
		
		public function init(name:String, alignA:String, alignB:String) {
			/********************************************************************************
			 * Create a new MosaicArray
			 */
			this._arrays[name] = new MosaicArray(this._mosaic, name, alignA, alignB);
			this._length++;
			return this._arrays[name];
		}
		
		public function length():uint {
			/********************************************************************************
			 * Length of the hash.
			 */
			return this._length;
		}
		
		// \/ PROXY
		flash.utils.flash_proxy override function getProperty(name:*):* {
			/********************************************************************************
			 * Get named array to perform operations.
			 * Mosaic.array.<name>
			 */
			var self = this;
			
			if (name in this._arrays) {
				// Exists, pass Object
				return this._arrays[name];
			} else {
				// Doesn't Exist, pass Constructor
				return function(alignA, alignB) { return self.init(name, alignA, alignB); }
			}
		}
		
		flash.utils.flash_proxy override function deleteProperty(name:*):Boolean {
			/********************************************************************************
			 * Delete an array.
			 * delete Mosaic.array.<name>
			 */
			this._arrays[name].splice(0); // Removes all tiles
			delete this._arrays[name];
			this._length--;
			return true;
		}
		
		flash.utils.flash_proxy override function callProperty(name:*, ...args):* {
			/********************************************************************************
			 * Creation of the array.
			 * alignA = args[0]
			 * alignB = args[1]
			 */
			return this.init(name, args[0], args[1]);
		}
	}

	class MosaicArray extends flash.utils.Proxy {
		
		private var _mosaic:Mosaic = null;
		
		private var _alignA:String; // Alignment corner for A (parent)
		private var _alignB:String; // Alignment corner for B (child)
		
		private var _name:String; // Name of the array set into MosaicArrays
		private var _array:Array; // Array of DisplayObjects
		
		public function MosaicArray(mosaic:Mosaic, name:String, alignA:String, alignB:String) {
			/********************************************************************************
			 * CONSTRUCTOR
			 */
			this._mosaic = mosaic;
			
			this._alignA = alignA;
			this._alignB = alignB;
			
			this._name = name;
			this._array = [];
		}
		
		// \/ ARRAY-LIKE INTERFACE
		public function push(...args):uint {
			/********************************************************************************
			 * Push a sequence of DisplayObjects to the end of the specified Mosaic array.
			 */
			if (args.length > 0) {
				// ****** Clone the array of DisplayObjects to a data structure to be edited.
				var objs:Array = args.slice(); // slice() as clone()
				
				// ****** Detect empty array
				if (this._array.length == 0) {
					// Empty, Simply add
					this._mosaic.addChild(objs[0]);
				} else {
					// Non empty, use the last item as parent
					objs.unshift(this._array[this._array.length - 1]);
				}
				
				if (objs.length > 1) {
					// ****** Tile
					this._mosaic.tile.apply(
						this._mosaic,
						[this._alignA, this._alignB]
						.concat(objs)
					);
				}
				
				// ****** Update [Array]
				this._array = this._array.concat(args); // [Array]
			}
			return this._array.length;
		}
		
		public function pop():Object {
			/********************************************************************************
			 * Pop the last item from the specified Mosaic array.
			 */
			var object = null;
			if (this._array.length > 0) {
				object = this._array.pop(); // [Array]
				this._mosaic.untile(object);
			}
			return object;
		}
		
		public function shift():Object {
			/********************************************************************************
			 * Shift the first item from the specified Mosaic array.
			 */
			var object = null;
			if (this._array.length > 0) {
				object = this._array.shift(); // [Array]
				this._mosaic.untile(object);
			}
			return object;
		}
		
		public function unshift(...args):uint {
			/********************************************************************************
			 * Unshift a sequence of DisplayObjects to the head of the specified Mosaic array.
			 */
			if (args.length > 0) {
				// ****** Clone the array of DisplayObjects to a data structure to be edited.
				var objs:Array = args.slice(); // slice() as clone()
				
				// ****** Align
				if (this._array.length == 0) {
					// Empty, Simply add
					this._mosaic.addChild(objs[0]);
				} else {
					// *** If the first element is already present, align the new first item to it
					objs[0].x = this._mosaic.xOf(this._array[0]);
					objs[0].y = this._mosaic.yOf(this._array[0]);
				
					// *** And attach it to the tail of the new items
					objs.push(this._array[0]);
				}
				
				// ****** Tile
				if (objs.length > 1) {
					this._mosaic.tile.apply(
						this._mosaic,
						[this._alignA, this._alignB]
						.concat(objs)
					);
				}
				
				// ****** Update [Array]
				this._array = args.concat(this._array); // [Array]
			}
		
			return this._array.length;
		}
		
		public function splice(...args):Array {
			/********************************************************************************
			 * Splice the specified array.
			 */
			// ****** Params
			var startIndex:int; // Starting point
			var deleteCount:Number = NaN; // (uint) if is NaN, delete everything after startIndex
			var objs:Array = []; // Objects to be inserted
			
			// ****** Prepare params
			for (var argi = 0; argi < args.length; argi++) {
				if (args[argi] is Number && argi == 0) startIndex = args[argi];
				else if (args[argi] is Number && argi == 1) deleteCount = args[argi];
				else {
					objs.push(args[argi]); // Push
				}
			}
			
			// ****** Tile added items
			if (objs.length > 0) {
				this._mosaic.tile.apply(
					this._mosaic,
					[this._alignA, this._alignB]
						.concat(this._array[startIndex - 1]) // to this parent
						.concat(objs) // add those
						.concat(this._array[startIndex]) // and realign following ones
				);
			}
			
			// ****** Untile deleted items
			if (isNaN(deleteCount)) {
				// *** All
				this._mosaic.untile.apply(this._mosaic, this._array);
			} else {
				// *** Some
				var kobjs = this._array.slice(startIndex, startIndex + deleteCount);
				this._mosaic.untile.apply(this._mosaic, kobjs);
			}
			
			return this._array.splice.apply(this._array, args); // [Array];
		}
		
		public function length():uint {
			/********************************************************************************
			 * Length of the specified Mosaic array.
			 */
			return this._array.length;
		}
		
		public function mold(...args):Mosaic {
			/********************************************************************************
			 * Molds each of the passed parametes with Mosaic.mold()
			 * Returns the container (like mold() returns the single object).
			 */
			var inlineProps = null;
			
			for each (var item in args) {
				if (item is Array) {
					// *** Mold
					if (inlineProps) item.push(inlineProps);
					this.push(Mosaic.mold.apply(this._mosaic, item));
				} else {
					// *** Additional properties
					inlineProps = item;
				}
			}
			return this._mosaic;
		}
		
		// \/ PROXY
		flash.utils.flash_proxy override function getProperty(name:*):* {
			/********************************************************************************
			 * Return by index.
			 * Note that I can't check if name is Number, since typeof(name) == "string"
			 */
			if (name is QName) {
				// Name
				return this._mosaic.getChildByName(name.localName);			
			} else if (name is String && name.search(/^[0-9]+$/) > -1) {
				// Index
				return this._array[uint(name)];
			} else {
				// null
				return null;
			}
		}
	}
}