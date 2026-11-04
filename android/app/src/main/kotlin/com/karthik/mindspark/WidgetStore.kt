package com.karthik.mindspark

import android.content.Context
import org.json.JSONArray
import org.json.JSONException

/** Quotes and the current position, kept natively so the widget works offline. */
object WidgetStore {
    private const val PREFS = "mindspark_widget"
    private const val KEY_QUOTES = "quotes_json"
    private const val KEY_INDEX = "index"

    data class WidgetQuote(val id: String, val text: String, val author: String)

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveQuotes(context: Context, json: String) {
        val currentId = currentQuote(context)?.id
        val index = parse(json).indexOfFirst { it.id == currentId }.coerceAtLeast(0)
        prefs(context).edit().putString(KEY_QUOTES, json).putInt(KEY_INDEX, index).apply()
    }

    fun quotes(context: Context): List<WidgetQuote> {
        val raw = prefs(context).getString(KEY_QUOTES, null) ?: return emptyList()
        return parse(raw)
    }

    fun currentQuote(context: Context): WidgetQuote? {
        val list = quotes(context)
        if (list.isEmpty()) return null
        return list[prefs(context).getInt(KEY_INDEX, 0).mod(list.size)]
    }

    fun advance(context: Context) {
        val size = quotes(context).size
        if (size == 0) return
        val next = (prefs(context).getInt(KEY_INDEX, 0) + 1).mod(size)
        prefs(context).edit().putInt(KEY_INDEX, next).apply()
    }

    private fun parse(json: String): List<WidgetQuote> = try {
        val array = JSONArray(json)
        (0 until array.length()).map { i ->
            val item = array.getJSONObject(i)
            WidgetQuote(item.getString("id"), item.getString("text"), item.optString("author", ""))
        }
    } catch (e: JSONException) {
        emptyList()
    }
}
