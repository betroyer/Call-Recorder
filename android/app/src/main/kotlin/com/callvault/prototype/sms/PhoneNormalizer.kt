package com.callvault.prototype.sms

/**
 * Normalize phone numbers for SMS send (strip spaces; PH 09… → +639…).
 */
object PhoneNormalizer {
    fun normalize(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return trimmed
        // Keep leading +, strip other non-digits.
        val hasPlus = trimmed.startsWith("+")
        val digits = trimmed.filter { it.isDigit() }
        if (digits.isEmpty()) return trimmed.replace(" ", "")
        // Philippine mobile: 09XXXXXXXXX → +639XXXXXXXXX
        if (digits.length == 11 && digits.startsWith("09")) {
            return "+63${digits.substring(1)}"
        }
        // 639XXXXXXXXX without plus
        if (digits.length == 12 && digits.startsWith("63")) {
            return "+$digits"
        }
        return if (hasPlus) "+$digits" else digits
    }
}
