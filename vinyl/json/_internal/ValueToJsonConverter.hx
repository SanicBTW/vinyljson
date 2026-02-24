package vinyl.json._internal;

import hxjsonast.Position;
import haxe.exceptions.ArgumentException;
import haxe.rtti.Rtti;
import haxe.ds.StringMap;
import hxjsonast.Json;

class ValueToJsonConverter
{
	public static function convert(input:Dynamic):Json
	{
		switch Type.typeof(input)
		{
			case TNull:
				return new Json(JNull, createDummyPosition());

			case TInt | TFloat:
				return new Json(JNumber(Std.string(input)), createDummyPosition());

			case TBool:
				return new Json(JBool(input), createDummyPosition());

			case TObject:
				var fields = Reflect.fields(input).map(field ->
					{
						final value = Reflect.field(input, field);
						return new JObjectField(field, createDummyPosition(), convert(value));
					});
					return new Json(JObject(fields), createDummyPosition());

			case TClass(String):
				return new Json(JString(input), createDummyPosition());

			case TClass(Array):
				var values = (input : Array<Dynamic>).map(value ->
					{
						return convert(value);
					});
				return new Json(JArray(values), createDummyPosition());

			case TClass(StringMap):
				var fields =
				[
					for (key => value in (input : StringMap<Dynamic>))
					{
						new JObjectField(key, createDummyPosition(), convert(value));
					}
				];
				return new Json(JObject(fields), createDummyPosition());

			case TClass(c) if (Rtti.hasRtti(c)):
				return convertClass(input, c);

			case TEnum(e):
				return convertEnum(input, e);

			case t:
				throw new ArgumentException('input', 'Invalid value type $t');
		}
	}

	private static function convertClass<T>(input:T, c:Class<T>):Json
	{
		final cdef = Rtti.getRtti(c);
		final cfields = cdef.fields.filter(Utils.filterClassFields);

		var fields = cfields.map(cfield ->
			{
				final name = Utils.getClassFieldJsonProperty(cfield);
				final value = Reflect.getProperty(input, cfield.name);

				return new JObjectField(name, createDummyPosition(), convert(value));
			});

		return new Json(JObject(fields), createDummyPosition());
	}

	private static function convertEnum<T>(input:T, e:Enum<T>):Json
	{
		// TODO
		final inpAsValue:EnumValue = cast input;

		final enumCtor = Type.enumConstructor(inpAsValue);
		final params = Type.enumParameters(inpAsValue);

		var fields:Array<JObjectField> = [
			new JObjectField(
				"@enum",
				createDummyPosition(),
				new Json(JString(e.getName()), createDummyPosition())
			),
			new JObjectField(
				"value",
				createDummyPosition(),
				new Json(JString(enumCtor), createDummyPosition())
			),
		];

		if (params.length > 0)
		{
			var paramsArray = params.map(p -> convert(p));
			fields.push(
				new JObjectField(
					"params",
					createDummyPosition(),
					new Json(JArray(paramsArray), createDummyPosition())
				)
			);
		}

		return new Json(JObject(fields), createDummyPosition());
	}

	private static inline function createDummyPosition():Position
	{
		return new Position(null, 0, 0);
	}
}