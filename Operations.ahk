class Operations {
	static fPressed := Map()

	static pPressed := Map()

	static waiting := Map()

	static Initialize(key) {
		Operations.fPressed[key] := false
		Operations.pPressed[key] := false
		Operations.waiting[key] := false
	}
}