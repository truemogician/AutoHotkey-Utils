#Include "./Utils.ahk"


/**
 * A static class storing and mapping the logical and physical states of keys.
 */
class KeyState {
	/**
	 * A readonly mapping of the physical states of keys using `GetKeyState` with `P` mode.
	 */
	class Physical {
		static __Item[key] => GetKeyState(key, "P")
	}

	/**
	 * A static class storing and mapping the logical state of keys.
	 * 
	 * When `UseSystemState` is `true`, the states are mapped from `GetKeyState`;
	 * otherwize, they are managed by the class itself.
	 */
	class Logical {
		static _Map := Map()
		static _Logger := ""
		static _LastPressedTimeMap := Map()
		static _LastReleasedTimeMap := Map()
		/**
		 * Whether to use the `GetKeyState` to retrieve the logical states of keys. Default is `true`.
		 */
		static UseSystemState := true
		static __Item[key] {
			get => this.UseSystemState ? GetKeyState(key) : this._Map.Has(key) ? this._Map[key] : false
			set {
				if (!this.UseSystemState)
					this._Map[key] := value
			}
		}
		/**
		 * A map recording the last pressed time of keys.
		 */
		static LastPressedTime => this._LastPressedTimeMap
		/**
		 * A map recording the last released time of keys.
		 */
		static LastReleasedTime => this._LastReleasedTimeMap

		static Initialize(key) {
			if (!this.UseSystemState)
				this._Map[key] := false
			this._LastPressedTimeMap[key] := 0
			this._LastReleasedTimeMap[key] := 0
		}
		static EnableLogging(logFile) {
			this._Logger := Logger(logFile)
		}
		static DisableLogging() {
			this._Logger := ""
		}
	}

	static SleepMode := ""

	static Initialize(key) {
		this.Logical.Initialize(key)
		return this
	}

	static Press(key, recordTime := false) {
		Send("{" key " Down}")
		this.Logical[key] := true
		if (recordTime)
			this.Logical.LastPressedTime[key] := Utils.SystemTime
		if (this.Logical._Logger != "")
			this.Logical._Logger.Log(key " Pressed")
		return this
	}

	static Release(key, recordTime := false) {
		Send("{" key " Up}")
		this.Logical[key] := false
		if (recordTime)
			this.Logical.LastReleasedTime[key] := Utils.SystemTime
		if (this.Logical._Logger != "")
			this.Logical._Logger.Log(key " Released")
		return this
	}

	static Click(key, holdTime := 50, recordTime := false) {
		if (holdTime <= 0) {
			Send(key)
			if (this.Logical._Logger != "")
				this.Logical._Logger.Log(key " Clicked")
		}
		else {
			this.Press(key, recordTime)
			Utils.Sleep(holdTime, this.SleepMode)
			this.Release(key, recordTime)
		}
		return this
	}
}

/**
 * Some common useful functionality for games. To use, instantiate a sub class, then bind the `Down` and `Up` methods to corresponding keys.
 */
class Functionality {
	class Base {
		Key := ""

		Down() {
		}

		Up() {
		}

		Register(key?, keys*) {
			if (!IsSet(key))
				key := this.Key
			for (k in [key, keys*]) {
				Hotkey(k . " Up", (*) => this.Up())
				Hotkey(k, (*) => this.Down())
			}
			return this
		}
	}

	class OptionalFunc {
		/**
		 * @param {String | Func} keyOrFunc Key code or function to be executed. Can be empty.
		 */
		__New(keyOrFunc) {
			if (keyOrFunc == "")
				this._Func := ""
			else if (Type(keyOrFunc) == "String")
				this._Func := () => KeyState.Click(keyOrFunc)
			else if (HasBase(keyOrFunc, Func.Prototype))
				this._Func := keyOrFunc
			else
				throw ValueError("Invalid parameter type: " Type(keyOrFunc))
		}

		Call() {
			if (this._Func != "")
				this._Func.Call()
		}
	}

	class Action {
		PressAction := ""
		ReleaseAction := ""

		/**
		 * Create an `Action` with a key code, an instance of `Functionality.Base`, or two functions.
		 * @param {String | Func | Functionality.OptionalFunc | Functionality.Base} param1 The first parameter for the constructor, accepting 3 types:
		 * - `String`: a key code representing the secondary key to be clicked.
		 * - `Func` | `Functionality.OptionalFunc`: a function to be executed when pressed.
		 * - `Functionality.Base`: an instance of a `Functionality` class.
		 * @param {Func | Functionality.OptionalFunc} param2 The optional second parameter for the "two function" signature, accepting 1 type:
		 * - `Func` | `Functionality.OptionalFunc`: a function to be executed when released.
		 */
		__New(param1, param2 := "") {
			if (Type(param1) == "String") {
				this.PressAction := () => KeyState.Press(param1)
				this.ReleaseAction := () => KeyState.Release(param1)
				KeyState.Initialize(param1)
			}
			else if (HasBase(param1, Functionality.Base.Prototype)) {
				this.PressAction := param1.Down.Bind(param1)
				this.ReleaseAction := param1.Up.Bind(param1)
			}
			else if (param1 == "" || HasBase(param1, Func.Prototype || HasBase(param1, Functionality.OptionalFunc.Prototype))) {
				if (param1 == "" && param2 == "")
					throw ValueError("param1 and param2 can't both be empty")
				if (param1 != "")
					this.PressAction := param1
				if (HasBase(param2, Func.Prototype) || HasBase(param2, Functionality.OptionalFunc.Prototype))
					this.ReleaseAction := param2
				else if (param2 != "")
					throw ValueError("Invalid type of param2: " . Type(param2))
			}
			else
				throw ValueError("Invalid type of param1: " . Type(param1))
		}

		/**
		 * @param {String | Func | Functionality.Base | Functionality.Action} action
		 */
		static From(action) {
			return Type(action) == "Functionality.Action" ? action : Functionality.Action(action)
		}

		Press() {
			if (this.PressAction != "")
				this.PressAction.Call()
		}

		Release() {
			if (this.ReleaseAction != "")
				this.ReleaseAction.Call()
		}
	}

	/**
	 * Perform the original action and record the key status.
	 */
	class Record extends Functionality.Base {
		_Triggered := false

		/**
		 * @param {String} key The key to record and perform the original action.
		 * @param {Boolean} recordTime Whether to record the pressed and released time of the key.
		 * @param {Boolean} noRepeat If true, the key down event won't be triggered repeatedly when holding the key. Default is false.
		 */
		__New(key, recordTime := false, noRepeat := false) {
			this.Key := key
			this.RecordTime := recordTime
			this.NoRepeat := noRepeat
			KeyState.Initialize(key)
		}

		/**
		 * @return Whether the action is performed. Only `false` when `NoRepeat` is `true` and the event has already been triggered.
		 */
		Down() {
			if (this.NoRepeat && this._Triggered)
				return false
			this._Triggered := true
			KeyState.Press(this.Key, this.RecordTime)
			return true
		}

		Up() {
			if (this.NoRepeat && !this._Triggered)
				return false
			this._Triggered := false
			KeyState.Release(this.Key)
			return true
		}
	}

	/**
	 * In many games, the player needs to hold down a key to perform an action.
	 * If the action lasts long enough, it would be a pain for fingers.
	 * This class would transfer quick click to toggling, while still preserve the original mode for long hold.
	 */
	class ToggleInHold extends Functionality.Base {
		_Triggered := false
		_SecondToggle := false

		/**
		 * @param {Integer} threshold Time threshold to distinguish long hold from quick click. Default is 200ms.
		 */
		__New(key, threshold := 200) {
			this.Key := key
			this.Threshold := threshold
			KeyState.Initialize(key)
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			if (KeyState.Logical[this.Key])
				this._SecondToggle := true
			else
				KeyState.Press(this.Key, true)
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			if (this._SecondToggle || Utils.SystemTime - KeyState.Logical.LastPressedTime[this.Key] > this.Threshold) {
				this._SecondToggle := false
				KeyState.Release(this.Key)
			}
		}
	}

	/**
	 * In many games, some keys are used to toggle certain status.
	 * But in some cases, the status only needs to be enabled for a short time, and clicking twice reduces reactivity.
	 * This class would transfer long hold to holding, which means that the status will be toggle when pressed and toggled back when released,
	 * while still preserve the original mode for quick click.
	 */
	class HoldInToggle extends Functionality.Base {
		_Triggered := false
		_LastTriggered := 0

		/**
		 * @param {Integer} threshold Time threshold to distinguish a long hold from a quick click. Default is 200ms.
		 * @param {Integer} pressTime The time to hold `key` for a click. Default is 50ms.
		 */
		__New(key, threshold := 200, pressTime := 50) {
			this.Key := key
			this.Threshold := threshold
			this.PressTime := pressTime
			KeyState.Initialize(key)
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			startTime := Utils.SystemTime
			this._LastTriggered := startTime
			SetTimer((*) {
				if (this._Triggered && startTime == this._LastTriggered)
					KeyState.Release(this.Key)
			}, -this.Threshold)
			KeyState.Press(this.Key)
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			if (KeyState.Logical[this.Key])
				KeyState.Release(this.Key)
			else
				KeyState.Click(this.Key, this.PressTime)
		}
	}

	/**
	 * In some situations, the player needs to click a key continuously, which is exhausting.
	 * This class allows you to perform such action at a specified frequency while holding the key.
	 */
	class HoldForContinuousClick extends Functionality.Base {
		_Triggered := false
		_ClickCount := -1

		/**
		 * @param {String} key The key to be continuously clicked.
		 * @param {Integer} interval The interval between two clicks. Default is 250ms.
		 * @param {Integer} pressTime The time the key will be hold for a press. Default is 50ms.
		 * @param {Integer} oscillation Oscillation for press time and interval, should be within [0, 1). Default is 0.
		 * @param {Integer} maxClick Maximum number of clicks when holding. Default is -1, meaning no limit for the maximum number of clicks.
		 * @param {Boolean} recordTime Whether to record the press time or not. Default is `false`
		 */
		__New(key, interval := 250, pressTime := 50, oscillation := 0, maxClick := -1, recordTime := false, sleepMode := "") {
			this.Key := key
			this.Interval := interval
			this.PressTime := pressTime
			this.Oscillation := oscillation
			this.MaxClick := maxClick
			this.RecordTime := recordTime
			this.SleepMode := sleepMode
			KeyState.Initialize(key)
		}

		_Sleep(time) {
			if (this.Oscillation == 0)
				Utils.Sleep(time, this.SleepMode)
			else
				Utils.Sleep(time * Random(1 - this.Oscillation, 1 + this.Oscillation))
		}

		_Loop() {
			loop {
				KeyState.Press(this.Key, this.RecordTime)
				this._Sleep(this.PressTime)
				if (!this._Triggered)
					break
				KeyState.Release(this.Key)
				++this._ClickCount
				if (this.MaxClick > 0 && this._ClickCount >= this.MaxClick)
					break
				this._Sleep(this.Interval)
			} until (!this._Triggered)
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			this._ClickCount := 0
			SetTimer(this._Loop.Bind(this), -1)
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			this._ClickCount := 0
			if (KeyState.Logical[this.Key])
				KeyState.Release(this.Key)
		}
	}

	/**
	 * Trigger different actions when a key is clicked multiple times.
	 */
	class MultiClick extends Functionality.Base {
		_LastPressed := 0
		_Count := 0
		_CountWhenPressed := 0

		/**
		 * @param {String | Func | Functionality.Base | Functionality.Action} action Action to be executed with a single click. If omitted, it defaults to clicking `key`.
		 * @param {Integer} threshold Time threshold to distinguish consecutive clicks from a new click.
		 * @param {(String | Func | Functionality.Base | Functionality.Action)[]} actions Additional actions to be executed when `key` is clicked multiple times, starting from the second click.
		 */
		__New(key, primary := "", threshold := 200, actions*) {
			this.Key := key
			this.Threshold := threshold
			this.Actions := Array(Functionality.Action.From(primary == "" ? key : primary))
			for (primary in actions)
				this.Actions.Push(Functionality.Action.From(primary))
			KeyState.Initialize(key)
		}

		Depth => this.Actions.Length

		_StartTimer(count, isPress) {
			Callback() {
				if (count != this._Count)
					return
				action := this.Actions[count]
				isPress ? action.Press() : action.Release()
			}
			SetTimer(Callback, -this.Threshold)
		}

		Down() {
			if (this._CountWhenPressed)
				return
			now := Utils.SystemTime
			this._Count := now - this._LastPressed > this.Threshold ? 1 : this._Count + 1
			this._LastPressed := now
			this._CountWhenPressed := this._Count
			if (this._Count < this.Depth)
				this._StartTimer(this._Count, true)
			else
				this.Actions[this.Depth].Press()
		}

		Up() {
			if (!this._CountWhenPressed)
				return
			if (this._CountWhenPressed < this.Depth) {
				this._StartTimer(this._CountWhenPressed, false)
				this._CountWhenPressed := 0
			}
			else {
				this._Count := this._CountWhenPressed := 0
				this.Actions[this.Depth].Release()
			}
		}
	}

	/**
	 * Trigger a secondary action when double clicked.
	 */
	class MultiClickSecondaryAction extends Functionality.Base {
		_Triggered := false
		_PrimaryLastPressed := 0
		_Count := 0
		_SecondaryTriggered := false

		/**
		 * @param {String | Func | Functionality.Base | Functionality.Action} secondaryAction The secondary key to press when double clicked.
		 * @param {Integer} timeout Maximum time between two clicks to be considered as a double click. Default is 200ms.
		 * @param {Integer} nthClick Number of continuous clicks required to trigger the secondary action. Must be greater or equal to 2.
		 * Default is 2, meaning the secondary action will be triggered when `key` is double clicked.
		 */
		__New(key, secondaryAction, timeout := 200, nthClick := 2) {
			this.Key := key
			this.PrimaryAction := key
			this.SecondaryAction := Functionality.Action.From(secondaryAction)
			this.Timeout := timeout
			if (nthClick < 2)
				throw ValueError("nthClick must be greater or equal to 2.")
			this.NthClick := nthClick
			KeyState.Initialize(key)
		}

		/**
		 * Primary action. Defaults to clicking `Key`.
		 */
		PrimaryAction {
			get => this._PrimaryAction
			set => this._PrimaryAction := Functionality.Action.From(Value)
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			now := Utils.SystemTime
			this._Count := now - this._PrimaryLastPressed <= this.Timeout ? this._Count + 1 : 1
			if (this._Count < this.NthClick) {
				this._PrimaryLastPressed := now
				this.PrimaryAction.Press()
			}
			else {
				this._SecondaryTriggered := true
				this.SecondaryAction.Press()
			}
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			if (!this._SecondaryTriggered)
				this.PrimaryAction.Release()
			else {
				this._Count := 0
				this._SecondaryTriggered := false
				this.SecondaryAction.Release()
			}
		}
	}

	/**
	 * Click one key and trigger some other actions at the same time.
	 */
	class OneToMany extends Functionality.Base {
		_Triggered := false

		/**
		 * @param {(String | Func | Functionality.Base | Functionality.Action)[]} otherActions Other actions to be triggered at the same time.
		 */
		__New(key, otherActions*) {
			this.Key := key
			this.OtherActions := Array()
			for (action in otherActions)
				this.OtherActions.Push(Functionality.Action.From(action))
			KeyState.Initialize(key)
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			KeyState.Press(this.Key)
			for (action in this.OtherActions)
				action.Press()
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			KeyState.Release(this.Key)
			for (action in this.OtherActions)
				action.Release()
		}
	}

	/**
	 * Trigger another key or arbitrary action when certain condition is met, e.g. when some modifier keys are pressed down.
	 */
	class TriggerAnotherWhen extends Functionality.Base {
		_Triggered := false
		_ConditionMet := 0

		/**
		 * @param {String} key Source key
		 * @param {String | Func} condition Could be a key code, indicating the modifier key to be pressed for the secondary key to be triggered, or a function for arbitrary condition.
		 * @param {String | Func | Functionality.Base | Functionality.Action} action The action to be executed when `condition` is met.
		 * @param {(String | Func | Functionality.Base | Functionality.Action)[]} conditionsAndActions Additional conditionals and actions. Format: `condition1`, `action1`, `condition2`, `action2`, etc.
		 */
		__New(key, condition, action, conditionsAndActions*) {
			this.Key := key
			this.DefaultAction := key
			this.Conditions := Array(HasBase(condition, Func.Prototype) ? condition : () => KeyState.Logical[condition])
			this.Actions := Array(Functionality.Action.From(action))
			if (conditionsAndActions.Length & 1)
				throw ValueError("Additional conditions and actions should come in pairs")
			if (conditionsAndActions.Length > 0)
				this.Add(conditionsAndActions*)
			KeyState.Initialize(key)
		}

		/**
		 * Default action when `condition` isn't met. Defaults to clicking `Key`.
		 */
		DefaultAction {
			get => this._DefaultAction
			set => this._DefaultAction := Functionality.Action.From(Value)
		}

		Add(condition, action, conditionsAndActions*) {
			if (conditionsAndActions.Length & 1)
				throw ValueError("Additional conditions and actions should come in pairs")
			this.Conditions.Push(HasBase(condition, Func.Prototype) ? condition : () => KeyState.Logical[condition])
			this.Actions.Push(Functionality.Action.From(action))
			for (item in conditionsAndActions) {
				if (A_Index & 1)
					this.Conditions.Push(HasBase(item, Func.Prototype) ? item : () => KeyState.Logical[item])
				else
					this.Actions.Push(Functionality.Action.From(item))
			}
			return this
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			this._ConditionMet := 0
			for (condition in this.Conditions)
				if (condition.Call()) {
					this._ConditionMet := A_Index
					break
				}
			if (this._ConditionMet == 0)
				this.DefaultAction.Press()
			else
				this.Actions[this._ConditionMet].Press()
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			if (this._ConditionMet == 0)
				this.DefaultAction.Release()
			else
				this.Actions[this._ConditionMet].Release()
		}
	}

	/**
	 * Perform specified actions, and prevent repetition optionally.
	 */
	class General extends Functionality.Base {
		_Triggered := false

		/**
		 * @param {Func} onPress Function to execute when pressed.
		 * @param {Func} onRelease Function to execute when released.
		 * @param {Boolean} noRepeat If true, the key down event won't be triggered repeatedly when holding the key. Default is false.
		 * @param {Object} state Context state to be assigned to `Functionality.General`. Default is empty.
		 */
		__New(onPress, onRelease := "", noRepeat := true, state := "") {
			if (state != "" && !HasBase(state, Object.Prototype))
				throw ValueError("state should be an object, not a " Type(state))
			if (state != "") {
				for (key, value in state.OwnProps())
					this.DefineProp(key, { Value: value })
			}
			if (onPress == "")
				onPress := () => {}
			else if (!HasBase(onPress, Func.Prototype))
				throw ValueError("onPress should be a function, not a " Type(onPress))
			this.OnPress := onPress.MaxParams == 0 ? onPress : onPress.Bind(this)
			if (onRelease == "")
				onRelease := () => {}
			else if (!HasBase(onRelease, Func.Prototype))
				throw ValueError("onRelease should be a function, not a " Type(onRelease))
			this.OnRelease := onRelease.MaxParams == 0 ? onRelease : onRelease.Bind(this)
			this.NoRepeat := noRepeat
		}

		/**
		 * @return Whether the action is performed. Only `false` when `NoRepeat` is `true` and the event has already been triggered.
		 */
		Down() {
			if (this.NoRepeat && this._Triggered)
				return
			this._Triggered := true
			this.OnPress.Call()
		}

		Up() {
			if (this.NoRepeat && !this._Triggered)
				return
			this._Triggered := false
			this.OnRelease.Call()
		}
	}

	/**
	 * Perform different actions when a key is pressed and released quickly or held for a while.
	 */
	class LongShortPress extends Functionality.Base {
		_Triggered := false

		/**
		 * @param {String | Func} shortFunc Function to be executed when the key is pressed and released quickly.
		 * @param {String | Func} longFunc Function to be executed when the key is held for a while.
		 * @param {Integer} threshold The duration in milliseconds to differentiate between short and long presses. Default is 200ms.
		 * @param {String | Func} pressFunc Function to be executed when the key is pressed. Default is empty.
		 */
		__New(shortFunc, longFunc, threshold := 200, pressFunc := "") {
			this.ShortFunc := Functionality.OptionalFunc(shortFunc)
			this.LongFunc := Functionality.OptionalFunc(longFunc)
			this.PressFunc := Functionality.OptionalFunc(pressFunc)
			this.Threshold := threshold
		}

		/**
		 * Execute additional functions before and/or after the release of a key when it is held for a while.
		 * @param {String} key
		 * @param {String | Func} longBeforeFunc
		 * @param {String | Func} longAfterFunc
		 * @param {Integer} threshold
		 * @returns {Functionality.LongShortPress}
		 */
		static ExecuteWhenLong(key, longBeforeFunc, longAfterFunc := "", threshold := 200) {
			lbf := Functionality.OptionalFunc(longBeforeFunc)
			laf := Functionality.OptionalFunc(longAfterFunc)
			lsp := Functionality.LongShortPress(
				() => KeyState.Release(key),
				() => (lbf.Call(), KeyState.Release(key), laf.Call()),
				threshold,
				() => KeyState.Press(key)
			)
			lsp.Key := key
			KeyState.Initialize(key)
			return lsp
		}

		/**
		 * Execute additional functions before and/or after the release of a key when it is pressed and released quickly.
		 * @param {String} key
		 * @param {String | Func} shortBeforeFunc
		 * @param {String | Func} shortAfterFunc
		 * @param {Integer} threshold
		 * @returns {Functionality.LongShortPress}
		 */
		static ExecuteWhenShort(key, shortBeforeFunc, shortAfterFunc := "", threshold := 200) {
			sbf := Functionality.OptionalFunc(shortBeforeFunc)
			saf := Functionality.OptionalFunc(shortAfterFunc)
			lsp := Functionality.LongShortPress(
				() => (sbf.Call(), KeyState.Release(key), saf.Call()),
				() => KeyState.Release(key),
				threshold,
				() => KeyState.Press(key)
			)
			lsp.Key := key
			KeyState.Initialize(key)
			return lsp
		}

		Down() {
			if (this._Triggered)
				return
			this._Triggered := true
			this._StartTime := Utils.SystemTime
			if (this.PressFunc != "")
				this.PressFunc.Call()
		}

		Up() {
			if (!this._Triggered)
				return
			this._Triggered := false
			if (Utils.SystemTime - this._StartTime >= this.Threshold)
				this.LongFunc.Call()
			else
				this.ShortFunc.Call()
		}
	}

	/**
	 * Double click is a common problem for mice, which is often caused by dust or the oxidation of the mouseswitch.
	 * While a more permanent solution is to replace the switch, this class provides a temporary solution by filtering out the second click.
	 */
	class FixDoubleClick extends Functionality.Base {
		/**
		 * @param {String} key The key with double click problem.
		 * @param {Integer} threshould The time threshold to distinguish anomalous double click. Default is 50ms.
		 */
		__New(key, threshold := 10, logFile := "") {
			this.Key := key
			this.Threshold := threshold
			this._PressIgnored := false
			this._ReleaseIgnored := false
			this._Window := ""
			KeyState.Initialize(key)
			if (logFile) {
				this._Logger := Logger(logFile)
				this._Count := 0
				this._PressIgnoreCount := 0
				this._ReleaseIgnoreCount := 0
			}
		}

		Down() {
			if (this._PressIgnored)
				return
			if (this._ReleaseIgnored) {
				this._ReleaseIgnored := false
				return
			}
			interval := Utils.SystemTime - KeyState.Logical.LastReleasedTime[this.Key]
			try curWindow := WinGetID("A")
			catch {
				curWindow := ""
			}
			if (interval > this.Threshold || (curWindow != "" && curWindow != this._Window)) {
				KeyState.Press(this.Key, true)
				this._Window := curWindow
			}
			else {
				this._PressIgnored := true
				if (this._Logger) {
					this._PressIgnoreCount++
					this._Logger.Log(Format("Double Clicked during Release: {1} ms ({2:.2f}%, {3:.2f}%, {4})", interval, this._PressIgnoreCount / this._Count * 100, (this._PressIgnoreCount + this._ReleaseIgnoreCount) / this._Count * 100, this._Count))
				}
			}
		}

		Up() {
			if (this._ReleaseIgnored)
				return
			this._Count++
			if (this._PressIgnored) {
				this._PressIgnored := false
				return
			}
			interval := Utils.SystemTime - KeyState.Logical.LastPressedTime[this.Key]
			try curWindow := WinGetID("A")
			catch {
				curWindow := ""
			}
			if (interval > this.Threshold || (curWindow != "" && curWindow != this._Window)) {
				KeyState.Release(this.Key, true)
				this._Window := curWindow
			}
			else {
				this._ReleaseIgnored := true
				if (this._Logger) {
					this._ReleaseIgnoreCount++
					this._Logger.Log(Format("Double Clicked during Press: {1} ms ({2:.2f}%, {3:.2f}%, {4})", interval, this._ReleaseIgnoreCount / this._Count * 100, (this._PressIgnoreCount + this._ReleaseIgnoreCount) / this._Count * 100, this._Count))
				}
			}
		}
	}
}