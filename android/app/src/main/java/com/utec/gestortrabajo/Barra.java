package com.utec.gestortrabajo;

import android.content.Intent;
import android.view.MenuItem;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.android.material.navigation.NavigationBarView;

// Barra inferior por rol (barra_cliente y barra_trabajador). Cada pestaña abre su pantalla y cierra la actual.
// Las pantallas compartidas, como Perfil, incluyen las dos barras: aquí se deja visible solo la del rol de la sesión.
public class Barra {

    // idPestanaActual es el elemento del menú de la pantalla que llama, por ejemplo R.id.btnBarraPerfil
    public static void preparar(final AppCompatActivity pantalla, int idPestanaActual) {
        BottomNavigationView barra = barraDelRol(pantalla);
        if (barra == null) {
            return;
        }
        // primero se marca la actual y después se escuchan los toques, para que marcarla no abra nada
        barra.setSelectedItemId(idPestanaActual);
        barra.setOnItemSelectedListener(new NavigationBarView.OnItemSelectedListener() {
            @Override
            public boolean onNavigationItemSelected(@NonNull MenuItem pestana) {
                return abrir(pantalla, pestana.getItemId());
            }
        });
    }

    // Muestra la barra del rol y oculta la otra, si la pantalla incluye las dos
    private static BottomNavigationView barraDelRol(AppCompatActivity pantalla) {
        String rol = new Sesion(pantalla).obtenerRol();
        BottomNavigationView barraCliente = pantalla.findViewById(R.id.barraCliente);
        BottomNavigationView barraTrabajador = pantalla.findViewById(R.id.barraTrabajador);
        mostrar(barraCliente, rol.equals("cliente"));
        mostrar(barraTrabajador, rol.equals("trabajador"));
        if (rol.equals("cliente")) {
            return barraCliente;
        }
        if (rol.equals("trabajador")) {
            return barraTrabajador;
        }
        return null;
    }

    private static void mostrar(View barra, boolean visible) {
        if (barra != null) {
            barra.setVisibility(visible ? View.VISIBLE : View.GONE);
        }
    }

    // Abre la pantalla de la pestaña tocada y cierra la actual. Devuelve false si el elemento no es una pestaña.
    private static boolean abrir(AppCompatActivity pantalla, int idPestana) {
        Class<?> destino = destinoDe(idPestana);
        if (destino == null) {
            return false;
        }
        pantalla.startActivity(new Intent(pantalla, destino));
        pantalla.finish();
        return true;
    }

    private static Class<?> destinoDe(int idPestana) {
        if (idPestana == R.id.btnBarraSolicitudes) {
            return MisSolicitudesActivity.class;
        }
        if (idPestana == R.id.btnBarraTrabajos) {
            return TrabajosZonaActivity.class;
        }
        if (idPestana == R.id.btnBarraPropuestas) {
            return MisPropuestasActivity.class;
        }
        if (idPestana == R.id.btnBarraPerfil) {
            return PerfilActivity.class;
        }
        return null;
    }
}
