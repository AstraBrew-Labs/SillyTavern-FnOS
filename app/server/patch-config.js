#!/usr/bin/env node
/**
 * 极简 YAML 标量/序列改写器（仅服务本应用的 config.yaml）。
 *
 * 用法：node patch-config.js <config.yaml> key=value [a.b=value] [key[]=v1,v2,v3] ...
 *   - 顶层标量：port=8000
 *   - 一层嵌套：basicAuthUser.username=admin
 *   - 序列：whitelist[]=127.0.0.1,192.168.0.0/16
 *   - 值前缀 "!" 表示按原生类型输出（true / false / 数字），否则一律输出字符串
 *
 * 设计取舍：SillyTavern 的 config.yaml 结构扁平（仅 basicAuthUser 一层嵌套，
 * whitelist 为块序列），用行级改写即可保留原有注释与未涉及的键，
 * 避免整体重写导致上游默认值与注释丢失。
 */
'use strict';

const fs = require('fs');

const argv = process.argv.slice(2);
const file = argv.shift();

if (!file || argv.length === 0) {
  console.error('usage: patch-config.js <file> key=value [key=value ...]');
  process.exit(2);
}

const lines = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').split(/\r?\n/) : [];
while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();

const quote = (value) => `'${value.replace(/'/g, "''")}'`;

const format = (raw) => (raw.startsWith('!') ? raw.slice(1) : quote(raw));

// 序列项：IPv4/CIDR 保持裸写（与上游默认配置一致），其余（如 IPv6 的 ::1）
// 加引号，避免 YAML 1.1 解析器把它读成 Symbol 之类的非字符串类型。
const PLAIN_SEQ = /^(?:\d{1,3}\.){3}\d{1,3}(?:\/\d{1,2})?$/;
const formatSeqItem = (item) => (PLAIN_SEQ.test(item) ? item : quote(item));

const blockEnd = (start) => {
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^[^\s#]/.test(lines[i])) return i;
  }
  return lines.length;
};

const replaceScalar = (key, value) => {
  const index = lines.findIndex((line) => new RegExp(`^${key}:`).test(line));
  if (index >= 0) lines[index] = `${key}: ${value}`;
  else lines.push(`${key}: ${value}`);
};

const replaceSequence = (key, items) => {
  const block = [`${key}:`, ...items.map((item) => `  - ${formatSeqItem(item)}`)];
  const start = lines.findIndex((line) => new RegExp(`^${key}:`).test(line));

  if (start === -1) {
    lines.push(...block);
    return;
  }

  let end = start + 1;
  while (end < lines.length && /^\s+-\s/.test(lines[end])) end += 1;
  lines.splice(start, end - start, ...block);
};

const replaceNested = (top, child, value) => {
  const start = lines.findIndex((line) => new RegExp(`^${top}:`).test(line));

  if (start === -1) {
    lines.push(`${top}:`, `  ${child}: ${value}`);
    return;
  }

  const end = blockEnd(start);
  let target = -1;
  for (let i = start + 1; i < end; i += 1) {
    if (new RegExp(`^\\s+${child}:`).test(lines[i])) {
      target = i;
      break;
    }
  }

  if (target >= 0) lines[target] = `  ${child}: ${value}`;
  else lines.splice(end, 0, `  ${child}: ${value}`);
};

let changed = 0;

for (const pair of argv) {
  const eq = pair.indexOf('=');
  if (eq < 1) continue;

  const rawKey = pair.slice(0, eq);
  const rawValue = pair.slice(eq + 1);

  if (rawKey.endsWith('[]')) {
    const items = rawValue.split(',').map((item) => item.trim()).filter(Boolean);
    replaceSequence(rawKey.slice(0, -2), items);
    changed += 1;
    continue;
  }

  const keyPath = rawKey.split('.');
  if (keyPath.length === 1) {
    replaceScalar(keyPath[0], format(rawValue));
  } else {
    replaceNested(keyPath[0], keyPath[1], format(rawValue));
  }
  changed += 1;
}

fs.writeFileSync(file, `${lines.join('\n')}\n`);
console.log(`patched ${changed} key(s) in ${file}`);
