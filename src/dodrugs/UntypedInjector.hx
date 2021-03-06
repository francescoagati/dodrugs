package dodrugs;

/**
UntypedInjector supplies the basic injection infrastructure to record mappings and provide values.

It is `Untyped` in the sense that it doesn't hold any information about which injector you are using, and provides no compile-time safety for checking if a value is injected as expected.

In general you should use `Injector<"my_id">` instead of `UntypedInjector`.
**/
class UntypedInjector {
	var parent:Null<UntypedInjector>;
	var mappings:InjectorMappings;

	function new( parent:Null<UntypedInjector>, mappings:InjectorMappings ) {
		this.parent = parent;
		this.mappings = mappings;
		if ( !mappings.exists('dodrugs.UntypedInjector') )
			mappings.set( 'dodrugs.UntypedInjector', function(_,_) return this );
	}

	/**
	Retrieve a value based on the current injector mappings.

	@param id The string identifier representing the mapping you wish to retrieve.
	@return The value supplied by the injector mapping. It is typed as `Any`, which can then be cast into the relevant type.
	@throws (String) An error message if no mapping was found for this ID.
	**/
	public inline function getFromId( id:String ):Any {
		return _get( id );
	}

	function _get(id: String, ?injectorThatRequested: UntypedInjector): Any {
		if (injectorThatRequested == null) {
			injectorThatRequested = this;
		}
		var wildcardId = id.split(' ')[0];
		return
			if (mappings.exists(id)) mappings[id](injectorThatRequested, id)
			else if (wildcardId != id && mappings.exists(wildcardId)) mappings[wildcardId](injectorThatRequested, wildcardId)
			else if (this.parent!=null) this.parent._get(id, injectorThatRequested)
			else throw 'The injection had no mapping for "$id" in injector "${untyped this.name}"';
	}

	/**
	Retrieve a value based on the current injector mappings, and if no mapping is found, use the fallback value.

	@param id The string identifier representing the mapping you wish to retrieve.
	@return The value supplied by the injector mapping, or if no mapping was found, the fallback value. The return value will have the same type as the fallback value.
	**/
	public inline function tryGetFromId<T>( id:String, fallback:T ):T {
		return _tryGet( id, fallback );
	}

	function _tryGet( id:String, fallback:Any ):Any {
		return
			try getFromId( id )
			catch (e:Dynamic) fallback;
	}

	function _getSingleton( injectorThatRequested: UntypedInjector, mapping:InjectorMapping<Any>, id:String ):Any {
		var val = mapping( this, id );
		injectorThatRequested.mappings[id] = function(_, _) return val;
		return val;
	}

	/**
	Fetch a value, using a mapping that exists on the parent injector if it exists, otherwise using the supplied mapping as a fallback.
	**/
	function _getPreferingParent(id: String, mapping: InjectorMapping<Any>) {
		var parent = this.parent;
		while (parent != null) {
			if (parent.mappings.exists(id)) {
				return parent.mappings[id](this, id);
			}
			parent = parent.parent;
		}
		return mapping(this, id);
	}

	// Macro helpers

	/**
	Get a value from the injector.

	This essentially is a shortcut for:

	`injector.getFromId(Injector.getInjectionString(MyClass));`

	@param typeExpr The object to request. See `InjectorStatics.getInjectionString()` for a description of valid formats.
	@return The requested object, with all injections applied. The return object will be correctly typed as the type you are requesting.
	@throws (String) An error if the injection cannot be completed. This should be very rare as you receive compile time warnings if a required injection was missing.
	**/
	public macro function get(ethis:haxe.macro.Expr, typeExpr:haxe.macro.Expr):haxe.macro.Expr {
		var injectionString = InjectorMacro.getInjectionStringFromExpr(typeExpr);
		var complexType = InjectorMacro.getComplexTypeFromIdExpr(typeExpr);
		// Get the Injector ID based on the current type of "this", and mark the current injection string as "required".
		switch haxe.macro.Context.typeof(ethis) {
			case TInst(_, [TInst(_.get() => { kind: KExpr({ expr: EConst(CString(injectorId)) }) },[])]):
				InjectorMacro.markInjectionStringAsRequired(injectorId, injectionString, typeExpr.pos);
			case _:
		}

		return macro ($ethis.getFromId($v{injectionString}):$complexType);
	}

	/**
	Try get a value from the injector, or use a fallback value if no value in the injector was found.

	This essentially is a shortcut for:

	`injector.tryGetFromId(Injector.getInjectionString(MyClass), fallback);`

	@param typeExpr The object to request. See `InjectorStatics.getInjectionString()` for a description of valid formats.
	@param fallback The fallback value to use if the injector did not have a matching mapping.
	@return The requested object, with all injections applied, or the fallback object. The return object will be correctly typed as the type you are requesting.
	**/
	public macro function tryGet(ethis:haxe.macro.Expr, typeExpr:haxe.macro.Expr, fallback:haxe.macro.Expr):haxe.macro.Expr {
		var injectionString = InjectorMacro.getInjectionStringFromExpr(typeExpr);
		var complexType = InjectorMacro.getComplexTypeFromIdExpr(typeExpr);

		return macro ($ethis.tryGetFromId($v{injectionString}, ($fallback:$complexType)):$complexType);
	}
}
