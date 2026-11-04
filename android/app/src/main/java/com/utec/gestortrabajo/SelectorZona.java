package com.utec.gestortrabajo;

import android.app.Activity;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.google.android.material.textfield.TextInputLayout;

import org.json.JSONException;

import java.util.ArrayList;

// Zona en cascada con tres campos iguales (los de campos_zona.xml): departamento, municipio y colonia.
// Cada uno abre una HojaSeleccion con la lista. Al cambiar un nivel se vacían los de abajo y se piden a la API los nuevos.
// Elige una colonia (cliente y nueva solicitud) o varias (colonias donde trabaja el trabajador).
// Lo usan el registro, el perfil y la nueva solicitud.
public class SelectorZona {

    private final Activity pantalla;
    private final TextInputLayout capaColonia;
    private final EditText edtDepartamento;
    private final EditText edtMunicipio;
    private final EditText edtColonia;

    private final ArrayList<ElementoCatalogo> departamentos = new ArrayList<ElementoCatalogo>();
    private final ArrayList<ElementoCatalogo> municipios = new ArrayList<ElementoCatalogo>();
    private final ArrayList<ElementoCatalogo> colonias = new ArrayList<ElementoCatalogo>();
    private final ArrayList<ElementoCatalogo> coloniasElegidas = new ArrayList<ElementoCatalogo>();
    private ElementoCatalogo departamento = null;
    private ElementoCatalogo municipio = null;
    private boolean varias = false;

    // Zona que se propone al llenar cada lista (la del perfil). Se usa una sola vez; 0 o vacío es "sin propuesta"
    private int departamentoPropuesto = 0;
    private int municipioPropuesto = 0;
    private ArrayList<Integer> coloniasPropuestas = new ArrayList<Integer>();

    public SelectorZona(Activity pantalla) {
        this.pantalla = pantalla;
        TextInputLayout capaDepartamento = pantalla.findViewById(R.id.capaDepartamento);
        TextInputLayout capaMunicipio = pantalla.findViewById(R.id.capaMunicipio);
        capaColonia = pantalla.findViewById(R.id.capaColonia);
        edtDepartamento = capaDepartamento.getEditText();
        edtMunicipio = capaMunicipio.getEditText();
        edtColonia = capaColonia.getEditText();

        abrirAlTocar(capaDepartamento, new Runnable() {
            @Override
            public void run() {
                tocarDepartamento();
            }
        });
        abrirAlTocar(capaMunicipio, new Runnable() {
            @Override
            public void run() {
                tocarMunicipio();
            }
        });
        abrirAlTocar(capaColonia, new Runnable() {
            @Override
            public void run() {
                tocarColonia();
            }
        });
        mostrarElegidas();
    }

    // Sin zona propuesta
    public void cargar() {
        cargar(0, 0, new ArrayList<Integer>());
    }

    // Pide los departamentos. La zona propuesta queda elegida cuando llega cada lista, si está en ella.
    public void cargar(int departamentoId, int municipioId, ArrayList<Integer> coloniaIds) {
        departamentoPropuesto = departamentoId;
        municipioPropuesto = municipioId;
        coloniasPropuestas = coloniaIds;
        ClienteApi.pedir(pantalla, "GET", "api/catalogos/departamentos", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                if (llenar(departamentos, cuerpo)) {
                    proponerDepartamento();
                }
            }

            @Override
            public void alError(int codigo, String mensaje) {
            }
        });
    }

    // true: varias colonias con casillas (trabajador); false: una sola. Al pasar a una sola se descartan las elegidas.
    public void elegirVarias(boolean varias) {
        this.varias = varias;
        if (!varias && coloniasElegidas.size() > 1) {
            coloniasElegidas.clear();
        }
        mostrarElegidas();
    }

    public int municipioId() {
        return municipio == null ? 0 : municipio.id;
    }

    // La colonia elegida cuando se elige una sola, o 0 si falta
    public int coloniaId() {
        return coloniasElegidas.isEmpty() ? 0 : coloniasElegidas.get(0).id;
    }

    // Las colonias elegidas cuando se eligen varias
    public ArrayList<Integer> coloniaIds() {
        ArrayList<Integer> ids = new ArrayList<Integer>();
        for (ElementoCatalogo colonia : coloniasElegidas) {
            ids.add(colonia.id);
        }
        return ids;
    }

    // El campo entero y su flecha abren la hoja
    private void abrirAlTocar(TextInputLayout capa, final Runnable abrir) {
        View.OnClickListener alTocar = new View.OnClickListener() {
            @Override
            public void onClick(View vista) {
                abrir.run();
            }
        };
        capa.getEditText().setOnClickListener(alTocar);
        capa.setEndIconOnClickListener(alTocar);
    }

    private void tocarDepartamento() {
        if (departamentos.isEmpty()) {
            Toast.makeText(pantalla, R.string.cargando, Toast.LENGTH_SHORT).show();
            return;
        }
        HojaSeleccion.mostrar(pantalla, R.string.titulo_elegir_departamento, departamentos, departamento,
                new HojaSeleccion.AlElegir() {
                    @Override
                    public void elegido(ElementoCatalogo elemento) {
                        elegirDepartamento(elemento);
                    }
                });
    }

    private void tocarMunicipio() {
        if (departamento == null) {
            Toast.makeText(pantalla, R.string.falta_departamento, Toast.LENGTH_SHORT).show();
            return;
        }
        if (municipios.isEmpty()) {
            Toast.makeText(pantalla, R.string.cargando, Toast.LENGTH_SHORT).show();
            return;
        }
        HojaSeleccion.mostrar(pantalla, R.string.titulo_elegir_municipio, municipios, municipio,
                new HojaSeleccion.AlElegir() {
                    @Override
                    public void elegido(ElementoCatalogo elemento) {
                        elegirMunicipio(elemento);
                    }
                });
    }

    private void tocarColonia() {
        if (municipio == null) {
            Toast.makeText(pantalla, R.string.falta_municipio, Toast.LENGTH_SHORT).show();
            return;
        }
        if (colonias.isEmpty()) {
            Toast.makeText(pantalla, R.string.cargando, Toast.LENGTH_SHORT).show();
            return;
        }
        if (varias) {
            HojaSeleccion.mostrarVarios(pantalla, R.string.titulo_elegir_colonias, colonias, coloniasElegidas,
                    new HojaSeleccion.AlElegirVarios() {
                        @Override
                        public void elegidos(ArrayList<ElementoCatalogo> marcadas) {
                            coloniasElegidas.clear();
                            coloniasElegidas.addAll(marcadas);
                            mostrarElegidas();
                        }
                    });
            return;
        }
        ElementoCatalogo actual = coloniasElegidas.isEmpty() ? null : coloniasElegidas.get(0);
        HojaSeleccion.mostrar(pantalla, R.string.titulo_elegir_colonia, colonias, actual, new HojaSeleccion.AlElegir() {
            @Override
            public void elegido(ElementoCatalogo colonia) {
                coloniasElegidas.clear();
                coloniasElegidas.add(colonia);
                mostrarElegidas();
            }
        });
    }

    private void proponerDepartamento() {
        int posicion = ElementoCatalogo.posicionDe(departamentos, departamentoPropuesto);
        if (posicion >= 0) {
            departamentoPropuesto = 0;
            elegirDepartamento(departamentos.get(posicion));
        }
    }

    // Al cambiar el departamento se vacían municipio y colonias y se piden los municipios nuevos
    private void elegirDepartamento(ElementoCatalogo elegido) {
        departamento = elegido;
        edtDepartamento.setText(elegido.nombre);
        municipio = null;
        edtMunicipio.setText("");
        municipios.clear();
        limpiarColonias();
        cargarMunicipios(elegido);
    }

    private void cargarMunicipios(final ElementoCatalogo deDepartamento) {
        ClienteApi.pedir(pantalla, "GET", "api/catalogos/departamentos/" + deDepartamento.id + "/municipios", null,
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String cuerpo) {
                        // si mientras tanto se eligió otro departamento, esta respuesta ya no sirve
                        if (deDepartamento != departamento) {
                            return;
                        }
                        if (llenar(municipios, cuerpo)) {
                            proponerMunicipio();
                        }
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                    }
                });
    }

    private void proponerMunicipio() {
        int posicion = ElementoCatalogo.posicionDe(municipios, municipioPropuesto);
        if (posicion >= 0) {
            municipioPropuesto = 0;
            elegirMunicipio(municipios.get(posicion));
        }
    }

    // Al cambiar el municipio se descartan las colonias elegidas y se piden las nuevas
    private void elegirMunicipio(ElementoCatalogo elegido) {
        municipio = elegido;
        edtMunicipio.setText(elegido.nombre);
        limpiarColonias();
        cargarColonias(elegido);
    }

    private void cargarColonias(final ElementoCatalogo deMunicipio) {
        ClienteApi.pedir(pantalla, "GET", "api/catalogos/municipios/" + deMunicipio.id + "/colonias", null,
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String cuerpo) {
                        if (deMunicipio != municipio) {
                            return;
                        }
                        if (llenar(colonias, cuerpo)) {
                            proponerColonias();
                        }
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                    }
                });
    }

    private void limpiarColonias() {
        colonias.clear();
        coloniasElegidas.clear();
        mostrarElegidas();
    }

    // Marca las propuestas que estén en la lista; si no hay y el municipio tiene una sola colonia, esa
    private void proponerColonias() {
        for (ElementoCatalogo colonia : colonias) {
            if (coloniasPropuestas.contains(colonia.id) && (varias || coloniasElegidas.isEmpty())) {
                coloniasElegidas.add(colonia);
            }
        }
        if (!coloniasElegidas.isEmpty()) {
            coloniasPropuestas = new ArrayList<Integer>();
        } else if (colonias.size() == 1) {
            coloniasElegidas.add(colonias.get(0));
        }
        mostrarElegidas();
    }

    // El campo de la colonia muestra los nombres elegidos; vacío deja ver la etiqueta
    private void mostrarElegidas() {
        capaColonia.setHint(varias ? R.string.hint_colonias_trabajo : R.string.hint_colonia);
        edtColonia.setText(TextUtils.join(", ", coloniasElegidas));
    }

    // Llena la lista con la respuesta del catálogo. Devuelve false si la respuesta no se pudo leer.
    private boolean llenar(ArrayList<ElementoCatalogo> lista, String cuerpo) {
        try {
            ArrayList<ElementoCatalogo> leidos = ElementoCatalogo.desdeJson(cuerpo);
            lista.clear();
            lista.addAll(leidos);
            return true;
        } catch (JSONException e) {
            Toast.makeText(pantalla, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return false;
        }
    }
}
