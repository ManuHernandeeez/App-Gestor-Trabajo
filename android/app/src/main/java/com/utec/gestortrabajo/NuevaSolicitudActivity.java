package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.textfield.TextInputLayout;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Pantalla del cliente: publicar una solicitud. La zona se elige en cascada (departamento, municipio y colonia)
// y de entrada se propone la del perfil del cliente.
public class NuevaSolicitudActivity extends AppCompatActivity {

    private EditText edtTitulo;
    private EditText edtDescripcion;
    private EditText edtPresupuesto;
    private EditText edtDireccion;
    private EditText edtOficio;
    private Button btnPublicar;
    private SelectorZona zona;

    private final ArrayList<ElementoCatalogo> oficios = new ArrayList<ElementoCatalogo>();
    private ElementoCatalogo oficio = null;
    private boolean publicando = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_nueva_solicitud);
        Ventana.preparar(this, findViewById(R.id.raiz));

        edtTitulo = findViewById(R.id.edtTitulo);
        edtDescripcion = findViewById(R.id.edtDescripcion);
        edtPresupuesto = findViewById(R.id.edtPresupuesto);
        edtDireccion = findViewById(R.id.edtDireccion);
        edtOficio = findViewById(R.id.edtOficio);
        btnPublicar = findViewById(R.id.btnPublicar);
        Mascara.dinero(edtPresupuesto);

        // si ya hay algo escrito, Atrás pregunta antes de perderlo
        Atras.proteger(this, new Atras.Regla() {
            @Override
            public Atras.Pregunta preguntar() {
                if (!hayDatos()) {
                    return null;
                }
                return Atras.descartar(R.string.descartar_solicitud_titulo, R.string.descartar_solicitud_mensaje);
            }
        });
        zona = new SelectorZona(this);

        // el campo entero y su flecha abren la lista de oficios
        View.OnClickListener alTocarOficio = new View.OnClickListener() {
            @Override
            public void onClick(View vista) {
                elegirOficio();
            }
        };
        edtOficio.setOnClickListener(alTocarOficio);
        TextInputLayout capaOficio = findViewById(R.id.capaOficio);
        capaOficio.setEndIconOnClickListener(alTocarOficio);

        cargarOficios();
        cargarPerfil();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Flecha de volver: hace lo mismo que el botón Atrás del teléfono, incluido el aviso
    public void volver(View vista) {
        getOnBackPressedDispatcher().onBackPressed();
    }

    // La zona no cuenta: se propone sola desde el perfil
    private boolean hayDatos() {
        return escrito(edtTitulo) || escrito(edtDescripcion) || escrito(edtPresupuesto) || escrito(edtDireccion)
                || oficio != null;
    }

    private boolean escrito(EditText campo) {
        return !campo.getText().toString().trim().isEmpty();
    }

    // Primero el perfil, para proponer su zona; si falla, igual se cargan los departamentos
    private void cargarPerfil() {
        ClienteApi.pedir(this, "GET", "api/perfil", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                proponerZona(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                zona.cargar();
            }
        });
    }

    private void proponerZona(String cuerpo) {
        Perfil perfil;
        try {
            perfil = new Perfil(new JSONObject(cuerpo));
        } catch (JSONException e) {
            zona.cargar();
            return;
        }
        zona.cargar(perfil.departamentoId, perfil.municipioId, perfil.colonias);
    }

    private void cargarOficios() {
        ClienteApi.pedir(this, "GET", "api/catalogos/oficios", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrarOficios(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
            }
        });
    }

    private void mostrarOficios(String cuerpo) {
        try {
            ArrayList<ElementoCatalogo> leidos = ElementoCatalogo.desdeJson(cuerpo);
            oficios.clear();
            oficios.addAll(leidos);
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
    }

    private void elegirOficio() {
        if (oficios.isEmpty()) {
            Toast.makeText(this, R.string.cargando, Toast.LENGTH_SHORT).show();
            return;
        }
        HojaSeleccion.mostrar(this, R.string.titulo_elegir_oficio, oficios, oficio, new HojaSeleccion.AlElegir() {
            @Override
            public void elegido(ElementoCatalogo elemento) {
                oficio = elemento;
                edtOficio.setText(elemento.nombre);
            }
        });
    }

    // Botón Publicar solicitud
    public void publicar(View vista) {
        if (publicando) {
            return;
        }
        String titulo = edtTitulo.getText().toString().trim();
        String descripcion = edtDescripcion.getText().toString().trim();
        String direccion = edtDireccion.getText().toString().trim();
        double presupuesto = Formato.numero(edtPresupuesto.getText().toString());
        int falta = validar(titulo, descripcion, presupuesto, direccion);
        if (falta != 0) {
            Toast.makeText(this, falta, Toast.LENGTH_SHORT).show();
            return;
        }

        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("oficioId", oficio.id);
            cuerpo.put("coloniaId", zona.coloniaId());
            cuerpo.put("titulo", titulo);
            cuerpo.put("descripcion", descripcion);
            cuerpo.put("presupuesto", presupuesto);
            cuerpo.put("direccionExacta", direccion);
        } catch (JSONException e) {
            return;
        }

        publicando = true;
        Ventana.ocupar(btnPublicar, R.string.publicando);
        ClienteApi.pedir(this, "POST", "api/solicitudes", cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                Toast.makeText(NuevaSolicitudActivity.this, R.string.solicitud_publicada, Toast.LENGTH_SHORT).show();
                finish();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                publicando = false;
                Ventana.liberar(btnPublicar, R.string.boton_publicar);
            }
        });
    }

    // Devuelve el texto a mostrar si falta algo, o 0 si está completo. El servidor vuelve a validar todo.
    private int validar(String titulo, String descripcion, double presupuesto, String direccion) {
        if (titulo.isEmpty()) {
            return R.string.falta_titulo;
        }
        if (descripcion.isEmpty()) {
            return R.string.falta_descripcion;
        }
        if (oficio == null) {
            return R.string.falta_oficio_solicitud;
        }
        if (zona.coloniaId() == 0) {
            return R.string.falta_colonia;
        }
        if (presupuesto <= 0) {
            return R.string.presupuesto_invalido;
        }
        if (direccion.isEmpty()) {
            return R.string.falta_direccion;
        }
        return 0;
    }
}
