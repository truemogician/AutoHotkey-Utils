class Logger {
	__New(filePath := "") {
		this.FilePath := filePath
		this.__File := FileOpen(filePath, FileExist(filePath) ? "a" : "w")
	}

	__Delete() {
		this.__File.Close()
	}

	Log(message) {
		this.__File.Write("[" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.") A_MSec "] " message "`n")
		handle := this.__File.Handle
	}

	Clear() {
		this.__File.Close()
		this.__File := FileOpen(this.FilePath, "w")
		this.__File.Write("")
	}
}