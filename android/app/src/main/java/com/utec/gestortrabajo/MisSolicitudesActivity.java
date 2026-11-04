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

// Pantalla del cliente: sus solicitudes, con filtro por estado.
public class MisSolicitudesActivity extends AppCompatActivity {

    // Mismo orden que el arreglo filtro_estados de arrays.xml; la primera posición es "Todas"
    private static final String[] ESTADOS = {"", "publicada", "asignada", "en_proceso", "finalizada", "cancelada", "vencida"};

    private ChipGroup filtroEstado;
    private ListView listaSolicitudes;
    private TextView txtVacio;
    private final ArrayList<SolicitudResumen> solicitudes = new ArrayList<SolicitudResumen>();
    private AdaptadorSolicitudes adaptador;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_mis_solicitudes);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraSolicitudes);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        TextView txtNombre = findViewById(R.id.txtNombre);
        txtNombre.setText(getString(R.string.hola_nombre, new Sesion(this).obtenerNombre()));

        txtVacio = findViewById(R.id.txtVacio);
        listaSolicitudes = findViewById(R.id.listaSolicitudes);
        adaptador = new AdaptadorSolicitudes(this, solicitudes);
        listaSolicitudes.setAdapter(adaptador);
        listaSolicitudes.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                abrirPropuestas(solicitudes.get(posicion));
            }
        });

        filtroEstado = findViewById(R.id.filtroEstado);
        Filtro.llenar(this, filtroEstado, getResources().getStringArray(R.array.filtro_estados), new Filtro.AlCambiar() {
            @Override
            public void cambio() {
                cargar();
            }
        });
        cargar();
    }

    // Al volver de otra pantalla se recarga: pudo publicarse una solicitud o aceptarse una propuesta
    @Override
    protected void onRestart() {
        super.onRestart();
        cargar();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Actualizar
    public void actualizar(View vista) {
        cargar();
    }

    // Botón Nueva solicitud
    public void nuevaSolicitud(View vista) {
        startActivity(new Intent(this, NuevaSolicitudActivity.class));
    }

    private void abrirPropuestas(SolicitudResumen solicitud) {
        Intent intent = new Intent(this, PropuestasActivity.class);
        intent.putExtra("solicitudId", solicitud.id);
        intent.putExtra("titulo", solicitud.titulo);
        intent.putExtra("zona", solicitud.zona);
        intent.putExtra("presupuesto", solicitud.presupuesto);
        intent.putExtra("estado", solicitud.estado);
        startActivity(intent);
    }

    private void cargar() {
        String estado = ESTADOS[Filtro.posicion(filtroEstado)];
        String ruta = "api/solicitudes/mias";
        if (!estado.isEmpty()) {
            ruta = ruta + "?estado=" + estado;
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
            solicitudes.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                solicitudes.add(new SolicitudResumen(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_solicitudes);
        txtVacio.setVisibility(solicitudes.isEmpty() ? View.VISIBLE : View.GONE);
    }
}
