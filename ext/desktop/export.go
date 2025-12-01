package main

import (
	"C"
	"git.taurusxin.com/taurusxin/ncmdump-go/ncmcrypt"
	//"unsafe"
)

// main 函数对于 buildmode=c-shared 是必须的，但不会被执行
func main() {}

//export ConvertFile
// 这里的输入和输出必须使用 C 语言的类型 (*C.char)
func ConvertFile(cFilePath *C.char, cOutputDir *C.char) *C.char {
	// 1. C String -> Go String
	filePath := C.GoString(cFilePath)
	outputDir := C.GoString(cOutputDir)

	// 2. 调用核心逻辑 (复用你之前的逻辑)
	ncm, err := ncmcrypt.NewNeteaseCloudMusic(filePath)
	if err != nil {
		return C.CString("读取失败: " + err.Error())
	}

	dumpResult, err := ncm.Dump(outputDir)
	if err != nil {
		return C.CString("转换失败: " + err.Error())
	}

	if dumpResult {
		success, err := ncm.FixMetadata(true)
		if !success || err != nil {
			return C.CString("转换成功但元数据修复失败: " + err.Error())
		}
	}

	// 返回 nil 代表成功，返回字符串代表错误信息
	return nil
}