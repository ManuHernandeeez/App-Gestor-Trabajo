package com.utec.gestortrabajo;

import android.content.Context;
import android.graphics.Color;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.ScrollView;

import androidx.activity.EdgeToEdge;
import androidx.activity.SystemBarStyle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.OnApplyWindowInsetsListener;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

public class Ventana {

    // Android dibuja la app bajo la barra de estado y la de navegación. Esto deja el contenido dentro,
    // y sube la pantalla cuando aparece el teclado.
    // La app es solo clara: los íconos de las barras del sistema van oscuros aunque el teléfono esté en modo oscuro.
    // Si la pantalla tiene un formulario (un ScrollView), tocar fuera de un campo cierra el teclado.
    public static void preparar(AppCompatActivity pantalla, View raiz) {
        EdgeToEdge.enable(pantalla,
                SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
                SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT));
        ViewCompat.setOnApplyWindowInsetsListener(raiz, new OnApplyWindowInsetsListener() {
            @Override
            public WindowInsetsCompat onApplyWindowInsets(View vista, WindowInsetsCompat insets) {
                Insets bordes = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.ime());
                vista.setPadding(bordes.left, bordes.top, bordes.right, bordes.bottom);
                // consumidos aquí, para que la barra inferior no los sume otra vez
                return WindowInsetsCompat.CONSUMED;
            }
        });
        cerrarTecladoAlTocarFuera(buscarScroll(raiz));
    }

    public static void ocultarTeclado(View vista) {
        InputMethodManager teclado = (InputMethodManager) vista.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        teclado.hideSoftInputFromWindow(vista.getWindowToken(), 0);
    }

    // Botón de una acción que va a la red: se desactiva y dice qué está haciendo, para que un segundo toque no repita la petición
    public static void ocupar(Button boton, int textoOcupado) {
        boton.setEnabled(false);
        boton.setText(textoOcupado);
    }

    public static void liberar(Button boton, int texto) {
        boton.setEnabled(true);
        boton.setText(texto);
    }

    private static ScrollView buscarScroll(View vista) {
        if (vista instanceof ScrollView) {
            return (ScrollView) vista;
        }
        if (vista instanceof ViewGroup) {
            ViewGroup grupo = (ViewGroup) vista;
            for (int i = 0; i < grupo.getChildCount(); i++) {
                ScrollView encontrado = buscarScroll(grupo.getChildAt(i));
                if (encontrado != null) {
                    return encontrado;
                }
            }
        }
        return null;
    }

    // El espacio libre del formulario se toca: el foco sale del campo (y se valida) y el teclado se cierra
    private static void cerrarTecladoAlTocarFuera(ScrollView scroll) {
        if (scroll == null || scroll.getChildCount() == 0) {
            return;
        }
        final View contenido = scroll.getChildAt(0);
        contenido.setFocusableInTouchMode(true);
        contenido.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        contenido.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View vista) {
                vista.requestFocus();
                ocultarTeclado(vista);
            }
        });
    }
}
