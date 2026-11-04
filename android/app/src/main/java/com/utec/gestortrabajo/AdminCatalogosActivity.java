package com.utec.gestortrabajo;

import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Pantalla del administrador: catálogos de oficios y de zonas con interruptor activo o inactivo.
// Las zonas se recorren por niveles: departamentos, y al tocar uno sus municipios, y al tocar uno sus colonias.
// Nada se borra: desactivar un elemento conserva el historial.
public class AdminCatalogosActivity extends AppCompatActivity {

    private static final int NIVEL_DEPARTAMENTOS = 0;
    private static final int NIVEL_MUNICIPIOS = 1;
    private static final int NIVEL_COLONIAS = 2;

    private MaterialButtonToggleGroup vistaPestana;
    private View vistaRuta;
    private TextView txtRuta;
    private TextView txtVacio;
    private Button btnAgregar;
    private final ArrayList<ElementoAdmin> elementos = new ArrayList<ElementoAdmin>();
    private AdaptadorCatalogoAdmin adaptador;
    private OnBackPressedCallback volverUnNivel;

    private int numeroDePedido = 0;
    private boolean enOficios = true;
    private int nivel = NIVEL_DEPARTAMENTOS;
    private ElementoAdmin departamento;
    private ElementoAdmin municipio;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_admin_catalogos);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraCatalogos);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        // se registra después del aviso de salir, así que tiene prioridad mientras esté activo
        volverUnNivel = new OnBackPressedCallback(false) {
            @Override
            public void handleOnBackPressed() {
                subir(null);
            }
        };
        getOnBackPressedDispatcher().addCallback(this, volverUnNivel);

        vistaRuta = findViewById(R.id.vistaRuta);
        txtRuta = findViewById(R.id.txtRuta);
        txtVacio = findViewById(R.id.txtVacio);
        btnAgregar = findViewById(R.id.btnAgregar);

        adaptador = new AdaptadorCatalogoAdmin(this, elementos, new AdaptadorCatalogoAdmin.AlCambiar() {
            @Override
            public void activar(ElementoAdmin elemento, boolean activo) {
                guardarActivo(elemento, activo);
            }

            @Override
            public void editar(ElementoAdmin elemento) {
                pedirNombre(R.string.editar_nombre, elemento.nombre, elemento);
            }
        });
        ListView listaCatalogo = findViewById(R.id.listaCatalogo);
        listaCatalogo.setAdapter(adaptador);
        listaCatalogo.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                abrir(elementos.get(posicion));
            }
        });

        vistaPestana = findViewById(R.id.vistaPestana);
        vistaPestana.addOnButtonCheckedListener(new MaterialButtonToggleGroup.OnButtonCheckedListener() {
            @Override
            public void onButtonChecked(MaterialButtonToggleGroup grupo, int idBoton, boolean marcado) {
                if (marcado) {
                    cambiarPestana(idBoton == R.id.btnPestanaOficios);
                }
            }
        });
        mostrarNivel();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Cerrar sesión: pide confirmar
    public void cerrarSesion(View vista) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.cerrar_sesion)
                .setMessage(R.string.cerrar_sesion_mensaje)
                .setPositiveButton(R.string.cerrar_sesion, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        new Sesion(AdminCatalogosActivity.this).cerrar();
                        startActivity(new Intent(AdminCatalogosActivity.this, LoginActivity.class));
                        finish();
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    // Flecha de la ruta: sube un nivel de las zonas
    public void subir(View vista) {
        if (nivel == NIVEL_COLONIAS) {
            nivel = NIVEL_MUNICIPIOS;
            municipio = null;
        } else if (nivel == NIVEL_MUNICIPIOS) {
            nivel = NIVEL_DEPARTAMENTOS;
            departamento = null;
        }
        mostrarNivel();
    }

    // Botón Agregar: crea en el nivel que se está viendo
    public void agregar(View vista) {
        pedirNombre(R.string.agregar_nombre, "", null);
    }

    private void cambiarPestana(boolean oficios) {
        enOficios = oficios;
        nivel = NIVEL_DEPARTAMENTOS;
        departamento = null;
        municipio = null;
        mostrarNivel();
    }

    // Tocar un departamento o un municipio abre el nivel de abajo. Los oficios y las colonias no abren nada.
    private void abrir(ElementoAdmin elemento) {
        if (enOficios || nivel == NIVEL_COLONIAS) {
            return;
        }
        if (nivel == NIVEL_DEPARTAMENTOS) {
            departamento = elemento;
            nivel = NIVEL_MUNICIPIOS;
        } else {
            municipio = elemento;
            nivel = NIVEL_COLONIAS;
        }
        mostrarNivel();
    }

    // Ajusta la ruta, el texto del botón y el aviso de Atrás al nivel actual, y carga la lista
    private void mostrarNivel() {
        boolean dentro = !enOficios && nivel != NIVEL_DEPARTAMENTOS;
        vistaRuta.setVisibility(dentro ? View.VISIBLE : View.GONE);
        volverUnNivel.setEnabled(dentro);
        adaptador.permitirAbrir(!enOficios && nivel != NIVEL_COLONIAS);
        txtRuta.setText(textoRuta());
        btnAgregar.setText(textoAgregar());
        cargar();
    }

    private String textoRuta() {
        if (nivel == NIVEL_MUNICIPIOS) {
            return departamento.nombre;
        }
        if (nivel == NIVEL_COLONIAS) {
            return departamento.nombre + " › " + municipio.nombre;
        }
        return "";
    }

    private int textoAgregar() {
        if (enOficios) {
            return R.string.agregar_oficio;
        }
        if (nivel == NIVEL_DEPARTAMENTOS) {
            return R.string.agregar_departamento;
        }
        return nivel == NIVEL_MUNICIPIOS ? R.string.agregar_municipio : R.string.agregar_colonia;
    }

    // Nombre del recurso en la API para el nivel actual
    private String coleccion() {
        if (enOficios) {
            return "oficios";
        }
        if (nivel == NIVEL_DEPARTAMENTOS) {
            return "departamentos";
        }
        return nivel == NIVEL_MUNICIPIOS ? "municipios" : "colonias";
    }

    private void cargar() {
        String ruta = "api/admin/" + coleccion();
        if (!enOficios && nivel == NIVEL_MUNICIPIOS) {
            ruta = ruta + "?departamentoId=" + departamento.id;
        } else if (!enOficios && nivel == NIVEL_COLONIAS) {
            ruta = ruta + "?municipioId=" + municipio.id;
        }

        elementos.clear();
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.cargando);
        txtVacio.setVisibility(View.VISIBLE);

        // si se cambia de pestaña o de nivel antes de que llegue la respuesta, la vieja se ignora
        final int mio = ++numeroDePedido;
        ClienteApi.pedir(this, "GET", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                if (mio == numeroDePedido) {
                    mostrar(cuerpo);
                }
            }

            @Override
            public void alError(int codigo, String mensaje) {
                if (mio == numeroDePedido) {
                    txtVacio.setText(R.string.error_cargar);
                }
            }
        });
    }

    private void mostrar(String cuerpo) {
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            elementos.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                elementos.add(new ElementoAdmin(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_catalogo);
        txtVacio.setVisibility(elementos.isEmpty() ? View.VISIBLE : View.GONE);
    }

    // Cuadro con un campo para el nombre. elemento es null al agregar y el elemento al editar.
    private void pedirNombre(int titulo, String nombreActual, final ElementoAdmin elemento) {
        final EditText edtNombre = new EditText(this);
        edtNombre.setText(nombreActual);
        edtNombre.setSelection(nombreActual.length());
        edtNombre.setSingleLine(true);
        edtNombre.setHint(R.string.hint_nombre_catalogo);

        // el campo se deja dentro de un contenedor para que tenga margen a los lados del cuadro
        int margen = getResources().getDimensionPixelSize(R.dimen.espacio_seccion);
        FrameLayout contenedor = new FrameLayout(this);
        contenedor.setPadding(margen, margen / 2, margen, 0);
        contenedor.addView(edtNombre);

        new MaterialAlertDialogBuilder(this)
                .setTitle(titulo)
                .setView(contenedor)
                .setPositiveButton(R.string.boton_guardar_nombre, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        String nombre = edtNombre.getText().toString().trim();
                        if (nombre.isEmpty()) {
                            Toast.makeText(AdminCatalogosActivity.this, R.string.falta_nombre_catalogo, Toast.LENGTH_SHORT).show();
                        } else if (elemento == null) {
                            crear(nombre);
                        } else {
                            guardarNombre(elemento, nombre);
                        }
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    // Un municipio lleva el departamento y una colonia el municipio donde se crean
    private void crear(String nombre) {
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("nombre", nombre);
            if (!enOficios && nivel == NIVEL_MUNICIPIOS) {
                cuerpo.put("departamentoId", departamento.id);
            } else if (!enOficios && nivel == NIVEL_COLONIAS) {
                cuerpo.put("municipioId", municipio.id);
            }
        } catch (JSONException e) {
            return;
        }
        ClienteApi.pedir(this, "POST", "api/admin/" + coleccion(), cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                Toast.makeText(AdminCatalogosActivity.this, R.string.catalogo_agregado, Toast.LENGTH_SHORT).show();
                cargar();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                // el mensaje de la API ya se mostró
            }
        });
    }

    private void guardarNombre(ElementoAdmin elemento, String nombre) {
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("nombre", nombre);
        } catch (JSONException e) {
            return;
        }
        editar(elemento, cuerpo, R.string.catalogo_guardado);
    }

    private void guardarActivo(ElementoAdmin elemento, boolean activo) {
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("activo", activo);
        } catch (JSONException e) {
            return;
        }
        editar(elemento, cuerpo, activo ? R.string.catalogo_activado : R.string.catalogo_desactivado);
    }

    // Después se recarga, salga bien o no, para que la lista y los interruptores muestren lo que quedó en el servidor
    private void editar(ElementoAdmin elemento, JSONObject cuerpo, final int mensajeListo) {
        ClienteApi.pedir(this, "PUT", "api/admin/" + coleccion() + "/" + elemento.id, cuerpo.toString(),
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String respuesta) {
                        Toast.makeText(AdminCatalogosActivity.this, mensajeListo, Toast.LENGTH_SHORT).show();
                        cargar();
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                        cargar();
                    }
                });
    }
}
