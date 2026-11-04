package com.utec.gestortrabajo;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.chip.ChipGroup;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;

// Pantalla del trabajador: los trabajos publicados en su zona y oficios, con filtro por oficio.
public class TrabajosZonaActivity extends AppCompatActivity {

    private ChipGroup filtroOficio;
    private TextView txtVacio;
    private final ArrayList<TrabajoZona> trabajos = new ArrayList<TrabajoZona>();
    private AdaptadorTrabajos adaptador;

    // La primera opción del filtro es "Todos los oficios", con id 0
    private final ArrayList<ElementoCatalogo> oficios = new ArrayList<ElementoCatalogo>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_trabajos_zona);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraTrabajos);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        TextView txtNombre = findViewById(R.id.txtNombre);
        txtNombre.setText(getString(R.string.hola_nombre, new Sesion(this).obtenerNombre()));

        txtVacio = findViewById(R.id.txtVacio);
        ListView listaTrabajos = findViewById(R.id.listaTrabajos);
        adaptador = new AdaptadorTrabajos(this, trabajos);
        listaTrabajos.setAdapter(adaptador);
        listaTrabajos.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                abrirDetalle(trabajos.get(posicion));
            }
        });

        filtroOficio = findViewById(R.id.filtroOficio);
        cargarOficios();
        Sincronizacion.alAbrirApp(this);
    }

    // Al volver del detalle se recarga la lista, por si el trabajador envió una propuesta
    @Override
    protected void onRestart() {
        super.onRestart();
        cargarTrabajos();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Actualizar
    public void actualizar(View vista) {
        cargarTrabajos();
    }

    private void abrirDetalle(TrabajoZona trabajo) {
        Intent intent = new Intent(this, DetalleTrabajoActivity.class);
        intent.putExtra("solicitudId", trabajo.id);
        startActivity(intent);
    }

    // El filtro se arma con el catálogo de oficios y, en cuanto está, se hace la primera carga de trabajos
    private void cargarOficios() {
        ClienteApi.pedir(this, "GET", "api/catalogos/oficios", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                armarFiltro(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtVacio.setText(R.string.error_cargar);
            }
        });
    }

    private void armarFiltro(String cuerpo) {
        try {
            ArrayList<ElementoCatalogo> leidos = ElementoCatalogo.desdeJson(cuerpo);
            oficios.clear();
            oficios.add(new ElementoCatalogo(0, getString(R.string.todos_oficios)));
            oficios.addAll(leidos);
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        String[] nombres = new String[oficios.size()];
        for (int i = 0; i < nombres.length; i++) {
            nombres[i] = oficios.get(i).nombre;
        }
        Filtro.llenar(this, filtroOficio, nombres, new Filtro.AlCambiar() {
            @Override
            public void cambio() {
                cargarTrabajos();
            }
        });
        cargarTrabajos();
    }

    private void cargarTrabajos() {
        if (oficios.isEmpty()) {
            cargarOficios();
            return;
        }
        int oficioId = oficios.get(Filtro.posicion(filtroOficio)).id;
        String ruta = "api/trabajos/zona";
        if (oficioId != 0) {
            ruta = ruta + "?oficioId=" + oficioId;
        }

        txtVacio.setText(R.string.cargando);
        txtVacio.setVisibility(View.VISIBLE);
        ClienteApi.pedir(this, "GET", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtVacio.setText(R.string.error_cargar);
            }
        });
    }

    private void mostrar(String cuerpo) {
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            trabajos.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                trabajos.add(new TrabajoZona(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_trabajos);
        txtVacio.setVisibility(trabajos.isEmpty() ? View.VISIBLE : View.GONE);
    }
}
