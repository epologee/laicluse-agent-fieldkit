#!/usr/bin/env swift
import Cocoa

let data = FileHandle.standardInput.readDataToEndOfFile()
guard let input = String(data: data, encoding: .utf8), !input.isEmpty else {
    fputs("No input on stdin\n", stderr)
    exit(1)
}

let plain = input.replacingOccurrences(
    of: "<[^>]+>",
    with: "",
    options: .regularExpression
)

let pasteboard = NSPasteboard.general
pasteboard.clearContents()

let htmlWithCharset = "<meta charset=\"utf-8\">" + input
if let htmlData = htmlWithCharset.data(using: .utf8) {
    pasteboard.setData(htmlData, forType: .html)
}
pasteboard.setString(plain, forType: .string)
