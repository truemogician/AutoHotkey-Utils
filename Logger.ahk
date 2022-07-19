class Logger {
	__New(filePath := "") {
		this.FilePath := filePath
		this.file := FileOpen(filePath, FileExist(filePath) ? "a" : "w")
	}

	__Delete() {
		this.file.Close()
	}

	Log(message) {
		this.file.Write("[" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.") A_MSec "] " message "`n")
		handle := this.file.Handle
	}

	Clear() {
		this.file.Close()
		this.file := FileOpen(this.FilePath, "w")
		this.file.Write("")
	}
}