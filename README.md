Mosaic - AS3 Layout Library
===========================

Helper to provide modular alignment between objects.  
Each object can be bound to just one other object. New binds will redefine the old one.

Usage
-----

```
  var a = new Mosaic();
  a.tile(Mosaic.BOTTOM_RIGHT, Mosaic.TOP_LEFT, sprite1, sprite2);
```

You can also add a chain of elements, using the same pair of parameters:

```
  a.tile(Mosaic.BOTTOM_RIGHT, Mosaic.BOTTOM_LEFT, sprite1, sprite2, sprite3, sprite4);
```

You can use the contract form:

```
  a.tile("br", "bl", sprite1, sprite2, sprite3, sprite4);
```

To remove:

```
  a.untile(sprite2);
```

If there are elements bound to the removed element, they will realign "falling"
in the place of the unbound element.

Note that normal `addChild()` also works, but it's automatically done on `tile()`:
```
  a.addChild(sprite1);
```

The Mosaic object supports also an Array-like structure, using this syntax:

```
  a.array.name(Mosaic.BOTTOM_RIGHT, Mosaic.TOP_LEFT);
  a.array.name.push(sprite1);
  obj = a.array.name.pop();
  obj = a.array.name.shift();
  a.array.name.unshift(sprite2);
  a.array.splice(2, 1, sprite3, sprite4);

  a.array.name[2]; // Positional get (arrya index)
  a.array.name["item"]; // Name get (getChildByName shortcut)
```

The Mosaic object supports also a "fast" creation for Display Objects, using `mold()`:

```
  var obj = Mosaic.mold(TextField, "name", { prop1: "data", onEvent: function(){}, ... })
  a.array.name.mold(
    [TextField, "name1", { prop1: "data", onEvent: function(){}, ... }],
    [TextField, "name2", { prop1: "data", onEvent: function(){}, ... }],
  );
```
