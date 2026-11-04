package com.utec.gestortrabajo;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.widget.Toast;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

// Único punto de acceso a la API. Cada petición corre en un Thread y responde en el hilo principal.
public class ClienteApi {

    // Lo mismo que acepta la API para la foto de perfil: 2 MB
    private static final int FOTO_MAXIMO = 2 * 1024 * 1024;
    // La foto elegida se achica a este lado mayor, en píxeles, y se guarda como JPG de esta calidad antes de subirla
    private static final int FOTO_LADO = 1024;
    private static final int FOTO_CALIDAD = 85;
    // Lado mayor, en píxeles, con que se muestran las fotos descargadas
    private static final int IMAGEN_LADO = 512;

    public interface Respuesta {
        void alExito(String cuerpo);

        void alError(int codigo, String mensaje);
    }

    // Solo se llama si la imagen se pudo descargar; si falla, la pantalla deja la que tenía
    public interface RespuestaImagen {
        void alRecibir(Bitmap imagen);
    }

    private static class Resultado {
        final int codigo;
        final String cuerpo;
        // Mensaje de la app cuando el error se detecta antes de enviar, por ejemplo una foto que no es JPG
        final String mensaje;

        Resultado(int codigo, String cuerpo, String mensaje) {
            this.codigo = codigo;
            this.cuerpo = cuerpo;
            this.mensaje = mensaje;
        }
    }

    // metodo: "GET", "POST" o "PUT". ruta: sin barra inicial, por ejemplo "api/auth/login". cuerpo puede ser null.
    public static void pedir(final Activity pantalla, final String metodo, final String ruta,
                             final String cuerpo, final Respuesta respuesta) {
        final String token = new Sesion(pantalla).obtenerToken();
        new Thread(new Runnable() {
            @Override
            public void run() {
                responder(pantalla, enviar(metodo, ruta, cuerpo, token), token != null, respuesta);
            }
        }).start();
    }

    // Sube la foto de perfil a api/perfil/foto como multipart/form-data, en el campo "foto".
    // Antes de enviar achica y comprime la foto, porque una tomada con la cámara pesa varios MB y la API acepta hasta 2 MB.
    public static void subirFoto(final Activity pantalla, final Uri foto, final Respuesta respuesta) {
        final String token = new Sesion(pantalla).obtenerToken();
        new Thread(new Runnable() {
            @Override
            public void run() {
                responder(pantalla, enviarFoto(pantalla, foto, token), token != null, respuesta);
            }
        }).start();
    }

    // Descarga una imagen servida por la API, por ejemplo la foto de perfil (ruta "fotos/abc.jpg")
    public static void pedirImagen(final Activity pantalla, final String ruta, final RespuestaImagen respuesta) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                final Bitmap imagen = descargarImagen(ruta);
                if (imagen == null) {
                    return;
                }
                pantalla.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        if (!pantalla.isFinishing()) {
                            respuesta.alRecibir(imagen);
                        }
                    }
                });
            }
        }).start();
    }

    // Si la pantalla ya se cerró, la respuesta se ignora
    private static void responder(final Activity pantalla, final Resultado resultado, final boolean conSesion,
                                  final Respuesta respuesta) {
        pantalla.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (pantalla.isFinishing()) {
                    return;
                }
                entregar(pantalla, resultado, conSesion, respuesta);
            }
        });
    }

    private static Resultado enviar(String metodo, String ruta, String cuerpo, String token) {
        // POST y PUT siempre llevan cuerpo, aunque sea vacío (aceptar, rechazar, retirar), para que viaje Content-Length
        byte[] datos = null;
        if (!metodo.equals("GET")) {
            datos = (cuerpo == null ? "" : cuerpo).getBytes(StandardCharsets.UTF_8);
        }
        String tipo = cuerpo == null ? null : "application/json; charset=utf-8";
        return conectar(metodo, ruta, tipo, datos, token);
    }

    private static Resultado enviarFoto(Activity pantalla, Uri foto, String token) {
        byte[] datos;
        try {
            datos = reducirFoto(pantalla.getContentResolver(), foto);
        } catch (IOException | SecurityException e) {
            return rechazo(pantalla, R.string.foto_no_leida);
        }
        if (datos == null) {
            return rechazo(pantalla, R.string.foto_no_leida);
        }
        if (datos.length > FOTO_MAXIMO) {
            return rechazo(pantalla, R.string.foto_muy_grande);
        }

        String limite = "GestorTrabajo" + System.currentTimeMillis();
        return conectar("POST", "api/perfil/foto", "multipart/form-data; boundary=" + limite,
                cuerpoMultipart(limite, datos), token);
    }

    // Decodifica la foto reducida, la endereza según la orientación de la cámara y la guarda como JPG.
    // Así sirve cualquier formato que el teléfono sepa abrir. Devuelve null si el archivo no es una imagen.
    private static byte[] reducirFoto(ContentResolver contenido, Uri foto) throws IOException {
        BitmapFactory.Options opciones = new BitmapFactory.Options();
        opciones.inJustDecodeBounds = true;
        InputStream medida = contenido.openInputStream(foto);
        if (medida == null) {
            return null;
        }
        try {
            BitmapFactory.decodeStream(medida, null, opciones);
        } finally {
            medida.close();
        }
        if (opciones.outWidth <= 0 || opciones.outHeight <= 0) {
            return null;
        }

        int escala = 1;
        while (Math.max(opciones.outWidth, opciones.outHeight) / (escala * 2) >= FOTO_LADO) {
            escala = escala * 2;
        }
        opciones.inJustDecodeBounds = false;
        opciones.inSampleSize = escala;
        InputStream imagen = contenido.openInputStream(foto);
        if (imagen == null) {
            return null;
        }
        Bitmap mapa;
        try {
            mapa = BitmapFactory.decodeStream(imagen, null, opciones);
        } finally {
            imagen.close();
        }
        if (mapa == null) {
            return null;
        }

        mapa = ajustarTamano(mapa);
        mapa = enderezar(mapa, gradosDeGiro(contenido, foto));
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        mapa.compress(Bitmap.CompressFormat.JPEG, FOTO_CALIDAD, salida);
        return salida.toByteArray();
    }

    // La reducción por potencias de 2 puede dejar la foto hasta el doble de FOTO_LADO; aquí queda en FOTO_LADO
    private static Bitmap ajustarTamano(Bitmap mapa) {
        int mayor = Math.max(mapa.getWidth(), mapa.getHeight());
        if (mayor <= FOTO_LADO) {
            return mapa;
        }
        float factor = (float) FOTO_LADO / mayor;
        return Bitmap.createScaledBitmap(mapa, Math.round(mapa.getWidth() * factor),
                Math.round(mapa.getHeight() * factor), true);
    }

    // Las fotos de la cámara guardan en sus datos EXIF cuánto girarlas; al volver a guardarlas como JPG se pierde, así que se aplica aquí
    private static int gradosDeGiro(ContentResolver contenido, Uri foto) {
        try {
            InputStream flujo = contenido.openInputStream(foto);
            if (flujo == null) {
                return 0;
            }
            try {
                int orientacion = new ExifInterface(flujo).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
                if (orientacion == ExifInterface.ORIENTATION_ROTATE_90) {
                    return 90;
                }
                if (orientacion == ExifInterface.ORIENTATION_ROTATE_180) {
                    return 180;
                }
                if (orientacion == ExifInterface.ORIENTATION_ROTATE_270) {
                    return 270;
                }
                return 0;
            } finally {
                flujo.close();
            }
        } catch (IOException e) {
            return 0;
        }
    }

    private static Bitmap enderezar(Bitmap mapa, int grados) {
        if (grados == 0) {
            return mapa;
        }
        Matrix giro = new Matrix();
        giro.postRotate(grados);
        return Bitmap.createBitmap(mapa, 0, 0, mapa.getWidth(), mapa.getHeight(), giro, true);
    }

    // Un error detectado en la app se entrega igual que un 400 de la API, con su propio mensaje
    private static Resultado rechazo(Activity pantalla, int idMensaje) {
        return new Resultado(400, "", pantalla.getString(idMensaje));
    }

    // Un solo campo "foto" con el JPG, separado por el límite como pide multipart/form-data
    private static byte[] cuerpoMultipart(String limite, byte[] datos) {
        byte[] inicio = ("--" + limite + "\r\n"
                + "Content-Disposition: form-data; name=\"foto\"; filename=\"foto.jpg\"\r\n"
                + "Content-Type: image/jpeg\r\n\r\n").getBytes(StandardCharsets.UTF_8);
        byte[] fin = ("\r\n--" + limite + "--\r\n").getBytes(StandardCharsets.UTF_8);

        ByteArrayOutputStream cuerpo = new ByteArrayOutputStream();
        cuerpo.write(inicio, 0, inicio.length);
        cuerpo.write(datos, 0, datos.length);
        cuerpo.write(fin, 0, fin.length);
        return cuerpo.toByteArray();
    }

    // tipoContenido y cuerpo pueden ser null (GET)
    private static Resultado conectar(String metodo, String ruta, String tipoContenido, byte[] cuerpo, String token) {
        HttpURLConnection conexion = null;
        try {
            conexion = (HttpURLConnection) new URL(Config.URL_BASE + ruta).openConnection();
            conexion.setRequestMethod(metodo);
            conexion.setConnectTimeout(8000);
            conexion.setReadTimeout(15000);
            conexion.setRequestProperty("Accept", "application/json");
            if (token != null) {
                conexion.setRequestProperty("Authorization", "Bearer " + token);
            }
            if (cuerpo != null) {
                conexion.setDoOutput(true);
                if (tipoContenido != null) {
                    conexion.setRequestProperty("Content-Type", tipoContenido);
                }
                OutputStream salida = conexion.getOutputStream();
                salida.write(cuerpo);
                salida.close();
            }
            int codigo = conexion.getResponseCode();
            InputStream flujo = codigo >= 400 ? conexion.getErrorStream() : conexion.getInputStream();
            return new Resultado(codigo, leer(flujo), null);
        } catch (IOException e) {
            return new Resultado(0, "", null);
        } finally {
            if (conexion != null) {
                conexion.disconnect();
            }
        }
    }

    private static Bitmap descargarImagen(String ruta) {
        HttpURLConnection conexion = null;
        try {
            conexion = (HttpURLConnection) new URL(Config.URL_BASE + ruta).openConnection();
            conexion.setConnectTimeout(8000);
            conexion.setReadTimeout(15000);
            if (conexion.getResponseCode() != 200) {
                return null;
            }
            byte[] datos = leerBytes(conexion.getInputStream(), FOTO_MAXIMO);
            return datos == null ? null : decodificar(datos);
        } catch (IOException e) {
            return null;
        } finally {
            if (conexion != null) {
                conexion.disconnect();
            }
        }
    }

    // Decodifica la imagen reducida (lado mayor cerca de IMAGEN_LADO) para no llenar la memoria con una foto grande
    private static Bitmap decodificar(byte[] datos) {
        BitmapFactory.Options opciones = new BitmapFactory.Options();
        opciones.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(datos, 0, datos.length, opciones);
        int escala = 1;
        while (Math.max(opciones.outWidth, opciones.outHeight) / (escala * 2) >= IMAGEN_LADO) {
            escala = escala * 2;
        }
        opciones.inJustDecodeBounds = false;
        opciones.inSampleSize = escala;
        return BitmapFactory.decodeByteArray(datos, 0, datos.length, opciones);
    }

    private static String leer(InputStream flujo) throws IOException {
        if (flujo == null) {
            return "";
        }
        return new String(leerBytes(flujo, Integer.MAX_VALUE), StandardCharsets.UTF_8);
    }

    // Lee todo el flujo y lo cierra. Devuelve null si pasa de maximo bytes.
    private static byte[] leerBytes(InputStream flujo, int maximo) throws IOException {
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int leidos;
        try {
            while ((leidos = flujo.read(buffer)) != -1) {
                salida.write(buffer, 0, leidos);
                if (salida.size() > maximo) {
                    return null;
                }
            }
        } finally {
            flujo.close();
        }
        return salida.toByteArray();
    }

    private static void entregar(Activity pantalla, Resultado resultado, boolean conSesion, Respuesta respuesta) {
        if (resultado.codigo >= 200 && resultado.codigo < 300) {
            respuesta.alExito(resultado.cuerpo);
        } else if (resultado.codigo == 401 && conSesion) {
            sesionVencida(pantalla);
        } else {
            String mensaje = mensajeDeError(pantalla, resultado);
            Toast.makeText(pantalla, mensaje, Toast.LENGTH_LONG).show();
            respuesta.alError(resultado.codigo, mensaje);
        }
    }

    // Un 401 con token enviado es sesión vencida o cuenta suspendida. Sin token (el login) es una clave mala.
    private static void sesionVencida(Activity pantalla) {
        new Sesion(pantalla).cerrar();
        Toast.makeText(pantalla, R.string.sesion_vencida, Toast.LENGTH_LONG).show();
        pantalla.startActivity(new Intent(pantalla, LoginActivity.class));
        pantalla.finish();
    }

    private static String mensajeDeError(Activity pantalla, Resultado resultado) {
        if (resultado.mensaje != null) {
            return resultado.mensaje;
        }
        if (resultado.codigo == 0) {
            return pantalla.getString(R.string.error_conexion);
        }
        try {
            String mensaje = new JSONObject(resultado.cuerpo).optString("mensaje", "");
            if (!mensaje.isEmpty()) {
                return mensaje;
            }
        } catch (JSONException e) {
            // el cuerpo no era el JSON de error de la API
        }
        return pantalla.getString(R.string.error_inesperado);
    }
}
