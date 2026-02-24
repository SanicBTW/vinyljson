package vinyl.json._internal;

import haxe.ds.StringMap;
import haxe.rtti.CType;
import haxe.exceptions.ArgumentException;
import haxe.rtti.Rtti;
import hxjsonast.Json;

class JsonToValueConverter
{
	public static function convert<T>(input:Json, ?c:Class<T>):T
	{
		if (c != null)
		{
			return convertClass(input, c);
		}

		switch input.value
		{
			case JString(s):
				return cast s;

			case JNumber(s):
				return cast Std.parseFloat(s);

			case JObject(fields):
				var result = {}
				var reqExtraParse:Bool = false;
				for (field in fields)
				{
					if (field.name.indexOf("@") == 0) // should always begin with a @
						reqExtraParse = true;

					Reflect.setField(result, field.name, convert(field.value));
				}

				if (reqExtraParse)
				{
					// TODO
					// just to be safe, even if the printed json has always the @ declaration at the beginning of the object, we want to avoid fixed indices
					final typeDecl:Null<String> = Lambda.find(Reflect.fields(result), (k) -> StringTools.startsWith(k, "@"));
					if (typeDecl == null)
						throw new ArgumentException('typeDecl', "couldn't find a type declaration in the converted object, please check the appropiate @ usage");

					final target:String = typeDecl.substring(1);
					return cast structCoreParse(target, result);
				}

				return cast result;

			case JArray(values):
				var result:Array<Dynamic> = [];
				for (value in values)
				{
					result.push(convert(value));
				}
				return cast result;

			case JBool(b):
				return cast b;

			case JNull:
				return null;
		}
	}

	private static function convertClass<T>(input:Json, c:Class<T>):T
	{
		if (!Rtti.hasRtti(c))
		{
			throw new ArgumentException('c', 'Class ${Type.getClassName(c)} has no RTTI');
		}

		final struct = convert(input);
		if (!Type.typeof(struct).match(TObject))
		{
			throw new ArgumentException('input', 'Input should contain object');
		}

		return struct2class(struct, c);
	}

	private static function structCoreParse(objType:String, struct:Dynamic):Dynamic
	{
		return switch (objType)
		{
			case "enum":
				struct2enum(struct);
			case _:
				throw new ArgumentException('objType', 'invalid parse type $objType');
		}
	}

	private static function struct2class<T>(struct:Dynamic, c:Class<T>):T
	{
		final cdef = Rtti.getRtti(c);
		final cfields = cdef.fields.filter(Utils.filterClassFields);

		final cfieldMap =
		[
			for (cfield in cfields)
			{
				Utils.getClassFieldJsonProperty(cfield) => cfield;
			}
		];

		final result = Type.createEmptyInstance(c);

		for (field in Reflect.fields(struct))
		{
			if (!cfieldMap.exists(field))
			{
				continue;
			}

			final cfield = cfieldMap.get(field);
			final value = Reflect.field(struct, field);

			Reflect.setProperty(result, cfield.name, convertValue(cfield.type, value));
		}

		return result;
	}

	private static function struct2enum(struct:Dynamic):EnumValue
	{
		final enumPath:String = Reflect.field(struct, "@enum");
		final enumValue:String = Reflect.field(struct, "value");
		final params:Array<Dynamic> = Reflect.hasField(struct, "params") ? Reflect.field(struct, "params") : [];

		final resolvedEnum:Null<Enum<Dynamic>> = Type.resolveEnum(enumPath);
		if (resolvedEnum == null)
			throw new ArgumentException('@enum', 'couldn\'t resolve $enumPath, is it loaded?');

		return resolvedEnum.createByName(enumValue, params);
	}

	private static function convertValue(ctype:CType, input:Dynamic):Any
	{
		final type = Type.typeof(input);
		switch type
		{
			case TNull:
				if (!isNullableType(ctype))
				{
					throw new ArgumentException('input', 'Invalid input type $type');
				}
				return null;

			// i dont think tint can be anything else than int okay?
			case TInt:
				if (!ctype.match(CAbstract('Int', [])))
					throw new ArgumentException('input', 'Invalid input type $type');

				return input;

			case TFloat:
				if (ctype.match(CAbstract('Int', [])))
				{
					return Math.floor(input);
				}
				else if (ctype.match(CAbstract('Float', [])) || ctype.match(CAbstract('Single', [])))
				{
					return input;
				}
				else
				{
					throw new ArgumentException('input', 'Invalid input type $type');
				}

			case TBool:
				if (!ctype.match(CAbstract('Bool', [])))
				{
					throw new ArgumentException('input', 'Invalid input type $type');
				}
				return input;

			case TObject:
				switch ctype
				{
					case CClass('StringMap', [paramCType]) | CAbstract('haxe.ds.Map', [CClass('String', []), paramCType]) | CTypedef('Map', [CClass('String', []), paramCType]):
						var result = new StringMap<Any>();
						for (field in Reflect.fields(input))
						{
							final value = Reflect.field(input, field);
							result.set(field, convertValue(paramCType, value));
						}
						return result;

					case CClass(name, _):
						return struct2class(input, Type.resolveClass(name));

					case _:
						return input;
				}

			case TClass(String):
				return Std.string(input);

			case TClass(Array):
				switch ctype
				{
					case CClass('Array', [paramCType]):
						var result:Array<Any> = input.map(value ->
							{
								return convertValue(paramCType, value);
							});
						return result;

					case _:
						throw new ArgumentException('input', 'Invalid input type $type');
				}

			case TEnum(e):
				// ctype is kinda useless? we already have the enum from the given type
				// this is kinda hard actually, i dont know if i should resolve the value here or just return it since we already converted it before hand?
				// TODO?
				return input;

			case _:
				throw new ArgumentException('input', 'Invalid input type $type');
		}
	}

	private static function isNullableType(ctype:CType):Bool
	{
		if (ctype.match(CAbstract('Float', [])))
		{
			return false;
		}
		else if (ctype.match(CAbstract('Int', [])))
		{
			return false;
		}
		else if (ctype.match(CAbstract('Single', [])))
		{
			return false;
		}
		else if (ctype.match(CAbstract('Bool', [])))
		{
			return false;
		}
		
		return true;
	}
}