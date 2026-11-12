import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;

class VerifyUploadKey {
  public static void main(String[] args) throws Exception {
    if (args.length != 1) throw new IllegalArgumentException("Pass android/key.properties");
    Path propertiesPath = Path.of(args[0]).toAbsolutePath();
    Properties p = new Properties();
    try (InputStream in = Files.newInputStream(propertiesPath)) { p.load(in); }
    for (String key : List.of("storeFile", "storePassword", "keyAlias", "keyPassword"))
      if (p.getProperty(key, "").isBlank()) throw new IllegalStateException("Missing signing field: " + key);
    File file = new File(p.getProperty("storeFile"));
    if (!file.isAbsolute()) file = propertiesPath.getParent().resolve("app").resolve(file.toPath()).toFile();
    KeyStore store = KeyStore.getInstance(file, p.getProperty("storePassword").toCharArray());
    String alias = p.getProperty("keyAlias");
    if (!store.isKeyEntry(alias)) throw new IllegalStateException("Upload alias is not a private key entry");
    store.getKey(alias, p.getProperty("keyPassword").toCharArray());
    X509Certificate cert = (X509Certificate) store.getCertificate(alias);
    if (alias.equals("androiddebugkey") || cert.getSubjectX500Principal().getName().contains("CN=Android Debug"))
      throw new IllegalStateException("Debug signing keys are forbidden for releases");
    cert.checkValidity();
    System.out.println("Upload key verified. Certificate SHA-256: " +
      HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(cert.getEncoded())));
  }
}
