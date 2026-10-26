package com.example.flutter_fiscal_lib_flutter_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.io.Reader
import java.io.StringReader
import javax.xml.XMLConstants
import javax.xml.transform.stream.StreamSource
import javax.xml.validation.SchemaFactory
import org.w3c.dom.ls.LSInput
import org.w3c.dom.ls.LSResourceResolver

class MainActivity : FlutterActivity() {
    private companion object {
        const val ACCESS_EXTERNAL_DTD = "http://javax.xml.XMLConstants/property/accessExternalDTD"
        const val ACCESS_EXTERNAL_SCHEMA = "http://javax.xml.XMLConstants/property/accessExternalSchema"
    }

    private val channelName = "flutter_fiscal_lib/xsd"
    private val secretChannelName = "flutter_fiscal_lib/secret"
    private val secretPreferences = "flutter_fiscal_lib_secrets"
    private val secretAlias = "flutter_fiscal_lib_aes"

    private class BundleResolver(
        private val resources: Map<String, String>,
    ) : LSResourceResolver {
        override fun resolveResource(
            type: String?,
            namespaceURI: String?,
            publicId: String?,
            systemId: String?,
            baseURI: String?,
        ): LSInput? {
            val name = systemId?.substringAfterLast('/') ?: return null
            val content = resources[systemId] ?: resources[name] ?: return null
            return MemoryInput(publicId, systemId, baseURI, content)
        }
    }

    private class MemoryInput(
        private var publicId: String?,
        private var systemId: String?,
        private var baseURI: String?,
        private var stringData: String,
    ) : LSInput {
        override fun getCharacterStream(): Reader = StringReader(stringData)
        override fun setCharacterStream(characterStream: Reader?) {
            stringData = characterStream?.readText() ?: ""
        }
        override fun getByteStream() = null
        override fun setByteStream(byteStream: java.io.InputStream?) = Unit
        override fun getStringData() = stringData
        override fun setStringData(stringData: String?) {
            this.stringData = stringData ?: ""
        }
        override fun getSystemId() = systemId
        override fun setSystemId(systemId: String?) {
            this.systemId = systemId
        }
        override fun getPublicId() = publicId
        override fun setPublicId(publicId: String?) {
            this.publicId = publicId
        }
        override fun getBaseURI() = baseURI
        override fun setBaseURI(baseURI: String?) {
            this.baseURI = baseURI
        }
        override fun getEncoding() = "UTF-8"
        override fun setEncoding(encoding: String?) = Unit
        override fun getCertifiedText() = true
        override fun setCertifiedText(certifiedText: Boolean) = Unit
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureSecretChannel(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "validate" && call.method != "validateBundle") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val schema = call.argument<String>("schema")
                val xml = call.argument<String>("xml")
                val resources = (call.argument<Map<*, *>>("resources") ?: emptyMap<Any, Any>())
                    .mapNotNull { (key, value) ->
                        if (key is String && value is String) key to value else null
                    }
                    .toMap()
                if (schema.isNullOrBlank() || xml.isNullOrBlank()) {
                    result.success(
                        mapOf(
                            "exitCode" to 1,
                            "stdout" to "",
                            "stderr" to "schema e XML são obrigatórios",
                        ),
                    )
                    return@setMethodCallHandler
                }
                try {
                    val factory = SchemaFactory.newInstance(
                        XMLConstants.W3C_XML_SCHEMA_NS_URI,
                    )
                    factory.setProperty(
                        ACCESS_EXTERNAL_DTD,
                        "",
                    )
                    factory.setProperty(
                        ACCESS_EXTERNAL_SCHEMA,
                        "",
                    )
                    if (call.method == "validateBundle") {
                        factory.resourceResolver = BundleResolver(resources)
                    }
                    val validator = factory
                        .newSchema(StreamSource(StringReader(schema)))
                        .newValidator()
                    validator.setProperty(
                        ACCESS_EXTERNAL_DTD,
                        "",
                    )
                    validator.setProperty(
                        ACCESS_EXTERNAL_SCHEMA,
                        "",
                    )
                    validator.validate(StreamSource(StringReader(xml)))
                    result.success(
                        mapOf("exitCode" to 0, "stdout" to "valid", "stderr" to ""),
                    )
                } catch (error: Exception) {
                    result.success(
                        mapOf(
                            "exitCode" to 1,
                            "stdout" to "",
                            "stderr" to (error.message ?: error.javaClass.simpleName),
                        ),
                    )
                }
            }
    }

    private fun configureSecretChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secretChannelName)
            .setMethodCallHandler { call, result ->
                val key = call.argument<String>("key")
                if (key.isNullOrBlank() || key.contains('/') || key.contains('\\')) {
                    result.error("INVALID_SECRET_KEY", "chave inválida", null)
                    return@setMethodCallHandler
                }
                try {
                    val preferences = getSharedPreferences(secretPreferences, Context.MODE_PRIVATE)
                    when (call.method) {
                        "read" -> {
                            val stored = preferences.getString(key, null)
                            result.success(stored?.let { decrypt(it) })
                        }
                        "write" -> {
                            val encoded = call.argument<String>("value")
                            if (encoded.isNullOrEmpty()) {
                                result.error("EMPTY_SECRET", "segredo vazio", null)
                            } else {
                                preferences.edit().putString(key, encrypt(encoded)).apply()
                                result.success(null)
                            }
                        }
                        "delete" -> {
                            preferences.edit().remove(key).apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SECRET_STORE_ERROR", error.message, null)
                }
            }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(secretAlias, null)
        if (existing is SecretKey) return existing
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                secretAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val combined = cipher.iv + cipher.doFinal(Base64.decode(value, Base64.DEFAULT))
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val combined = Base64.decode(value, Base64.DEFAULT)
        require(combined.size > 12) { "segredo cifrado inválido" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            secretKey(),
            GCMParameterSpec(128, combined.copyOfRange(0, 12)),
        )
        return Base64.encodeToString(
            cipher.doFinal(combined.copyOfRange(12, combined.size)),
            Base64.NO_WRAP,
        )
    }
}
