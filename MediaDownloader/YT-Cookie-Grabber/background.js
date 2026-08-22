// background.js
const PASS_KEY_STR = "yt_dlp_assistant_secret_key_2026"; 

async function encryptData(text) {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(PASS_KEY_STR.padEnd(32, "0").slice(0, 32)),
    { name: "AES-CBC" },
    false,
    ["encrypt"]
  );

  const iv = crypto.getRandomValues(new Uint8Array(16));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: iv },
    keyMaterial,
    enc.encode(text)
  );

  const combined = new Uint8Array(iv.length + encrypted.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(encrypted), iv.length);

  let binary = "";
  for (let i = 0; i < combined.byteLength; i++) {
    binary += String.fromCharCode(combined[i]);
  }
  return btoa(binary);
}

chrome.action.onClicked.addListener(async () => {
  const cookies = await chrome.cookies.getAll({ domain: "youtube.com" });
  if (!cookies || cookies.length === 0) return;

  let netscapeText = "# Netscape HTTP Cookie File\n# http://curl.haxx.se/rfc/cookie_spec.html\n\n";
  for (const c of cookies) {
    const domain = c.domain.startsWith(".") ? c.domain : "." + c.domain;
    const includeSubdomains = c.domain.startsWith(".") ? "TRUE" : "FALSE";
    const path = c.path || "/";
    const secure = c.secure ? "TRUE" : "FALSE";
    const expiration = c.expirationDate ? Math.floor(c.expirationDate) : 0;
    netscapeText += `${domain}\t${includeSubdomains}\t${path}\t${secure}\t${expiration}\t${c.name}\t${c.value}\n`;
  }

  const encryptedPayload = await encryptData(netscapeText);
  const dataUrl = "data:application/octet-stream;base64," + btoa(encryptedPayload);

  chrome.downloads.download({
    url: dataUrl,
    filename: "youtube_cookies.ytdlp-vault",
    conflictAction: "overwrite",
    saveAs: false
  });
});