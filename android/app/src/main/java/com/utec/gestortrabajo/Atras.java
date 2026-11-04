package com.utec.gestortrabajo;

import android.content.DialogInterface;

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;

// Pide confirmar antes de salir de una pantalla con el botón Atrás del teléfono o con la flecha de la barra.
// Las pantallas principales preguntan siempre, porque ahí Atrás cierra la app; los formularios, solo si hay algo escrito.
public class Atras {

    // Lo que dice el aviso: título, mensaje y los dos botones (el primero sale, el segundo se queda)
    public static class Pregunta {
        private final int titulo;
        private final int mensaje;
        private final int botonSalir;
        private final int botonSeguir;

        public Pregunta(int titulo, int mensaje, int botonSalir, int botonSeguir) {
            this.titulo = titulo;
            this.mensaje = mensaje;
            this.botonSalir = botonSalir;
            this.botonSeguir = botonSeguir;
        }
    }

    // Se consulta en cada Atrás. Devuelve null cuando se puede salir sin preguntar.
    public interface Regla {
        Pregunta preguntar();
    }

    // Aviso de las pantallas principales, donde Atrás cierra la aplicación
    public static Pregunta salirDeLaApp() {
        return new Pregunta(R.string.salir_titulo, R.string.salir_mensaje, R.string.boton_salir, R.string.boton_quedarme);
    }

    // Aviso de un formulario con datos escritos que todavía no se guardaron ni se enviaron
    public static Pregunta descartar(int titulo, int mensaje) {
        return new Pregunta(titulo, mensaje, R.string.boton_salir, R.string.boton_seguir_editando);
    }

    public static void proteger(final AppCompatActivity pantalla, final Regla regla) {
        pantalla.getOnBackPressedDispatcher().addCallback(pantalla, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                final OnBackPressedCallback esta = this;
                Pregunta pregunta = regla.preguntar();
                if (pregunta == null) {
                    salir(esta, pantalla);
                } else {
                    preguntar(esta, pantalla, pregunta);
                }
            }
        });
    }

    public static void protegerSiempre(AppCompatActivity pantalla, final Pregunta pregunta) {
        proteger(pantalla, new Regla() {
            @Override
            public Pregunta preguntar() {
                return pregunta;
            }
        });
    }

    private static void preguntar(final OnBackPressedCallback aviso, final AppCompatActivity pantalla, Pregunta pregunta) {
        new MaterialAlertDialogBuilder(pantalla)
                .setTitle(pregunta.titulo)
                .setMessage(pregunta.mensaje)
                .setPositiveButton(pregunta.botonSalir, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        salir(aviso, pantalla);
                    }
                })
                .setNegativeButton(pregunta.botonSeguir, null)
                .show();
    }

    // Se apaga el aviso y se repite el Atrás, que ahora hace lo de siempre: cerrar la pantalla
    private static void salir(OnBackPressedCallback aviso, AppCompatActivity pantalla) {
        aviso.setEnabled(false);
        pantalla.getOnBackPressedDispatcher().onBackPressed();
    }
}
