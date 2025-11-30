package bridge

import (
	"fmt"
	//"path/filepath"
	"git.taurusxin.com/taurusxin/ncmdump-go/ncmcrypt"
)

// ConvertFile 是我们要暴露给安卓的方法
// 返回值：空字符串表示成功，非空字符串表示错误信息
func ConvertFile(filePath string, outputDir string) string {
	// 1. 读取文件
	ncm, err := ncmcrypt.NewNeteaseCloudMusic(filePath)
	if err != nil {
		return fmt.Sprintf("读取失败: %s", err.Error())
	}

	// 2. 转换 (Dump)
	// 如果 outputDir 为空，ncmdump 逻辑默认是在原目录，但在安卓上可能需要显式指定
	dumpResult, err := ncm.Dump(outputDir)
	if err != nil {
		return fmt.Sprintf("转换失败: %s", err.Error())
	}

	// 3. 修复元数据 (FixMetadata)
	if dumpResult {
		// 这里设置为 true，允许联网下载封面
		success, err := ncm.FixMetadata(true)
		if !success || err != nil {
			// 注意：即使元数据修复失败，文件可能已经转换成功了，
			// 这里视情况决定是返回错误还是仅返回警告
			return fmt.Sprintf("转换成功但元数据修复失败: %s", err.Error())
		}
	}

	return "" // 成功
}