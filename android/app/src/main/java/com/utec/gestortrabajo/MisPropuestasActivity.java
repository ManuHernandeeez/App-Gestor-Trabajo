package com.utec.gestortrabajo;

import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.chip.ChipGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;

// Pantalla del trabajador: sus propuestas, con filtro por estado y Retirar en las pendientes.
public class MisPropuestasActivity extends AppCompatActivity {

    // Mismo orden que el arreglo filtro_propuestas de arrays.xml; la primera posición es "Todas"
    private static final String[] ESTADOS = {"", "pendiente", "aceptada", "rechazada", "retirada"};

    private ChipGroup filtroEstado;
    private TextView txtVacio;
    private final ArrayList<PropuestaPropia> propuestas = new ArrayList<PropuestaPropia>();
    private AdaptadorPropuestasPropias adaptador;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_mis_propuestas);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraPropuestas);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        TextView txtNombre = findViewById(R.id.txtNombre);
        txtNombre.setText(getString(R.string.hola_nombre, new Sesion(this).obtenerNombre()));
        txtVacio = findViewById(R.id.txtVacio);

        adaptador = new AdaptadorPropuestasPropias(this, propuestas, new AdaptadorPropuestasPropias.AlRetirar() {
            @Override
            public void retirar(PropuestaPropia propuesta) {
                confirmarRetirar(propuesta);
            }
        });
        ListView listaPropuestas = findViewById(R.id.listaPropuestas);
        listaPropuestas.setAdapter(adaptador);
        listaPropuestas.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                abrirDetalle(propuestas.get(posicion));
            }
        });

        filtroEstado = findViewById(R.id.filtroEstado);
        Filtro.llenar(this, filtroEstado, getResources().getStringArray(R.array.filtro_propuestas), new Filtro.AlCambiar() {
            @Override
            public void cambio() {
                cargar();
            }
        });
        cargar();
    }

    // Al volver del detalle se recarga, por si la propuesta cambió
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

    // Una propuesta aceptada lleva al seguimiento del trabajo; las demás, al detalle para verla o reenviarla
    private void abrirDetalle(PropuestaPropia propuesta) {
        Class<?> destino = propuesta.estado.equals("aceptada") ? SeguimientoActivity.class : DetalleTrabajoActivity.class;
        Intent intent = new Intent(this, destino);
        intent.putExtra("solicitudId", propuesta.solicitudId);
        startActivity(intent);
    }

    private void cargar() {
        String estado = ESTADOS[Filtro.posicion(filtroEstado)];
        String ruta = "api/propuestas/mias";
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
            propuestas.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                propuestas.add(new PropuestaPropia(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_mis_propuestas);
        txtVacio.setVisibility(propuestas.isEmpty() ? View.VISIBLE : View.GONE);
    }

    private void confirmarRetirar(final PropuestaPropia propuesta) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.retirar_titulo)
                .setMessage(getString(R.string.retirar_mensaje, Formato.dinero(propuesta.precio), propuesta.titulo))
                .setPositiveButton(R.string.boton_retirar, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        retirar(propuesta);
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    private void retirar(PropuestaPropia propuesta) {
        if (ocupado) {
            return;
        }
        ocupado = true;
        ClienteApi.pedir(this, "PUT", "api/propuestas/" + propuesta.id + "/retirar", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                ocupado = false;
                Toast.makeText(MisPropuestasActivity.this, R.string.propuesta_retirada_ok, Toast.LENGTH_SHORT).show();
                cargar();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                ocupado = false;
                cargar();
            }
        });
    }
}
