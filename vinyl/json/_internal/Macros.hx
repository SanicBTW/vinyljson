package vinyl.json._internal;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

class Macros
{
	public static macro function addRtti():Array<Field>
	{
		final classRef = Context.getLocalClass();

		if (!classRef.get().meta.has(':rtti'))
		{
			classRef.get().meta.add(':rtti', [], Context.currentPos());
		}

		return Context.getBuildFields();
	}
}