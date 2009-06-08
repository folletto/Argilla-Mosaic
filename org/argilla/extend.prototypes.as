/*
 * Argilla Automate Chain
 * version 0.1
 *
 * last revision: 2007 12 04
 *
 * Copyright (C) 2007 Davide Casali, Alessandro Morandi. All Rights Reserved.
 * Released under GNU LGPL 2.1.
 * 
 * by Davide 'Folletto' Casali <folletto AT gmail DOT com>
 *    Alessandro 'Simbul' Morandi <a DOT morandi AT gmail DOT com>
 *
 */

/*
 * Chaining component.
 * Create an array of functions and call().
 * 
 *   var afx:Array = [a, b, c]; // where a, b, c are Functions
 *   afx.call(this, "parameter1", parameter2);
 * 
 */

Array.prototype.call = function(thisObject:*, ...params) {
	/********************************************************************************
	 * Call a chain of functions passing any parameter.
	 * A function needs to call the this.call() method to pass control to the next one.
	 */
	if ("rings" in this) {
		// ****** Next Chain Ring
		this.rings(); // NEXT --@-- CHAIN
	} else {
		// ****** Initialize Chain
		this.rings = function() {
			if (this.length > 0 && this[0] is Function) {
				this[0].next = this.rings; // attach NEXT --@-- CHAIN
				var func = this.shift();
				func.apply(thisObject, params);
			} else {
				delete this.rings;
			}
		}
		this.setPropertyIsEnumerable("rings", false);

		this.rings(); // --@-- CHAIN
	}
}
Array.prototype.setPropertyIsEnumerable("call", false);
