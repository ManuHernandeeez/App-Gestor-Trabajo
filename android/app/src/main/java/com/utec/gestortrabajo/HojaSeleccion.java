package com.utec.gestortrabajo;

import android.app.Activity;
import android.graphics.Color;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.view.WindowManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;

import androidx.core.view.WindowCompat;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.google.android.material.bottomsheet.BottomSheetDialog;

import java.util.ArrayList;
import java.util.HashSet;

// Hoja que sube desde abajo para elegir de una lista, con un buscador que filtra mientras se escribe.
// mostrar elige una sola al tocarla; mostrarVarios marca varias con casillas y las devuelve al tocar Aceptar.
public class HojaSeleccion {

    public interface AlElegir {
        void elegido(ElementoCatalogo elemento);
    }

    public interface AlElegirVarios {
        void elegidos(ArrayList<ElementoCatalogo> elementos);
    }

    // Con tan pocas opciones el buscador sobra y la hoja se ajusta a la lista
    private static final int OPCIONES_SIN_BUSCADOR = 7;

    // actual es la opción que ya estaba elegida, o null
    public static void mostrar(Activity pantalla, int titulo, final ArrayList<ElementoCatalogo> elementos,
                               ElementoCatalogo actual, final AlElegir alElegir) {
        final BottomSheetDialog hoja = new BottomSheetDialog(pantalla);
        final View vista = preparar(pantalla, titulo, elementos);
        final ListView lista = vista.findViewById(R.id.listaElementos);

        final ArrayList<ElementoCatalogo> visibles = new ArrayList<ElementoCatalogo>(elementos);
        final ArrayAdapter<ElementoCatalogo> adaptador =
                new ArrayAdapter<ElementoCatalogo>(pantalla, R.layout.item_opcion, visibles);
        final int idActual = actual == null ? 0 : actual.id;
        lista.setChoiceMode(ListView.CHOICE_MODE_SINGLE);
        lista.setAdapter(adaptador);
        marcarActual(lista, visibles, idActual);
        int posicionActual = ElementoCatalogo.posicionDe(visibles, idActual);
        if (posicionActual > 0) {
            lista.setSelection(posicionActual);
        }

        filtrarAlEscribir(vista, elementos, visibles, new Runnable() {
            @Override
            public void run() {
                adaptador.notifyDataSetChanged();
                marcarActual(lista, visibles, idActual);
            }
        });

        lista.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View fila, int posicion, long id) {
                alElegir.elegido(visibles.get(posicion));
                hoja.dismiss();
            }
        });
        abrir(hoja, vista);
    }

    // marcados son los que ya estaban elegidos. Devuelve los marcados en el orden de la lista.
    public static void mostrarVarios(Activity pantalla, int titulo, final ArrayList<ElementoCatalogo> elementos,
                                     ArrayList<ElementoCatalogo> marcados, final AlElegirVarios alElegir) {
        final BottomSheetDialog hoja = new BottomSheetDialog(pantalla);
        final View vista = preparar(pantalla, titulo, elementos);
        final ListView lista = vista.findViewById(R.id.listaElementos);

        // Los marcados se guardan por id, porque al filtrar cambian las posiciones de la lista
        final HashSet<Integer> ids = new HashSet<Integer>();
        for (ElementoCatalogo elemento : marcados) {
            ids.add(elemento.id);
        }

        final ArrayList<ElementoCatalogo> visibles = new ArrayList<ElementoCatalogo>(elementos);
        final ArrayAdapter<ElementoCatalogo> adaptador =
                new ArrayAdapter<ElementoCatalogo>(pantalla, R.layout.item_opcion_multiple, visibles);
        lista.setChoiceMode(ListView.CHOICE_MODE_MULTIPLE);
        lista.setAdapter(adaptador);
        marcarCasillas(lista, visibles, ids);

        filtrarAlEscribir(vista, elementos, visibles, new Runnable() {
            @Override
            public void run() {
                adaptador.notifyDataSetChanged();
                marcarCasillas(lista, visibles, ids);
            }
        });

        // Al tocar una fila la lista ya cambió su casilla; aquí solo se anota
        lista.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View fila, int posicion, long id) {
                int elementoId = visibles.get(posicion).id;
                if (lista.isItemChecked(posicion)) {
                    ids.add(elementoId);
                } else {
                    ids.remove(elementoId);
                }
            }
        });

        View btnAceptar = vista.findViewById(R.id.btnAceptar);
        btnAceptar.setVisibility(View.VISIBLE);
        btnAceptar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alElegir.elegidos(marcadosEn(elementos, ids));
                hoja.dismiss();
            }
        });
        abrir(hoja, vista);
    }

    // Arma el contenido: título y, si hay muchas opciones, buscador y una altura fija para que no salte al filtrar
    private static View preparar(Activity pantalla, int titulo, ArrayList<ElementoCatalogo> elementos) {
        View vista = pantalla.getLayoutInflater().inflate(R.layout.hoja_seleccion, null);
        ((TextView) vista.findViewById(R.id.txtTitulo)).setText(titulo);
        if (elementos.size() <= OPCIONES_SIN_BUSCADOR) {
            vista.findViewById(R.id.capaBuscar).setVisibility(View.GONE);
        } else {
            ListView lista = vista.findViewById(R.id.listaElementos);
            lista.getLayoutParams().height = (int) (pantalla.getResources().getDisplayMetrics().heightPixels * 0.45f);
        }
        return vista;
    }

    // La hoja sale ya desplegada y, con el teclado abierto para buscar, se acomoda sobre él
    private static void abrir(BottomSheetDialog hoja, View vista) {
        hoja.setContentView(vista);
        hoja.getBehavior().setState(BottomSheetBehavior.STATE_EXPANDED);
        hoja.getBehavior().setSkipCollapsed(true);
        hoja.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        hoja.show();
        // al mostrarse, la hoja deja su propia barra de navegación; se pone blanca con íconos oscuros, como la hoja
        hoja.getWindow().setNavigationBarColor(Color.WHITE);
        WindowCompat.getInsetsController(hoja.getWindow(), vista).setAppearanceLightNavigationBars(true);
    }

    // Al escribir en el buscador se filtra la lista y se avisa para refrescarla
    private static void filtrarAlEscribir(final View vista, final ArrayList<ElementoCatalogo> todos,
                                          final ArrayList<ElementoCatalogo> visibles, final Runnable alFiltrar) {
        EditText edtBuscar = vista.findViewById(R.id.edtBuscar);
        final View txtVacio = vista.findViewById(R.id.txtVacio);
        edtBuscar.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence texto, int inicio, int cantidad, int despues) {
            }

            @Override
            public void onTextChanged(CharSequence texto, int inicio, int antes, int cantidad) {
            }

            @Override
            public void afterTextChanged(Editable texto) {
                filtrar(todos, visibles, texto.toString());
                alFiltrar.run();
                txtVacio.setVisibility(visibles.isEmpty() ? View.VISIBLE : View.GONE);
            }
        });
    }

    // Deja en visibles los elementos cuyo nombre contiene el texto, sin importar mayúsculas ni tildes
    private static void filtrar(ArrayList<ElementoCatalogo> todos, ArrayList<ElementoCatalogo> visibles, String texto) {
        String buscado = Formato.sinTildes(texto.trim());
        visibles.clear();
        for (ElementoCatalogo elemento : todos) {
            if (Formato.sinTildes(elemento.nombre).contains(buscado)) {
                visibles.add(elemento);
            }
        }
    }

    private static void marcarActual(ListView lista, ArrayList<ElementoCatalogo> visibles, int idActual) {
        lista.clearChoices();
        int posicion = ElementoCatalogo.posicionDe(visibles, idActual);
        if (posicion >= 0) {
            lista.setItemChecked(posicion, true);
        }
    }

    private static void marcarCasillas(ListView lista, ArrayList<ElementoCatalogo> visibles, HashSet<Integer> ids) {
        lista.clearChoices();
        for (int i = 0; i < visibles.size(); i++) {
            lista.setItemChecked(i, ids.contains(visibles.get(i).id));
        }
    }

    private static ArrayList<ElementoCatalogo> marcadosEn(ArrayList<ElementoCatalogo> todos, HashSet<Integer> ids) {
        ArrayList<ElementoCatalogo> marcados = new ArrayList<ElementoCatalogo>();
        for (ElementoCatalogo elemento : todos) {
            if (ids.contains(elemento.id)) {
                marcados.add(elemento);
            }
        }
        return marcados;
    }
}
