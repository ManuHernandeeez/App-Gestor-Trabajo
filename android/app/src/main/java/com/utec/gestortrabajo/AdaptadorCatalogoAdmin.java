package com.utec.gestortrabajo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import com.google.android.material.materialswitch.MaterialSwitch;

import java.util.ArrayList;

// Filas de un catálogo para el administrador: nombre, lápiz para editarlo e interruptor activo o inactivo.
// Si el nivel tiene hijos (departamento y municipio) se muestra una flecha y tocar la fila los abre.
public class AdaptadorCatalogoAdmin extends BaseAdapter {

    public interface AlCambiar {
        void activar(ElementoAdmin elemento, boolean activo);

        void editar(ElementoAdmin elemento);
    }

    private final Context contexto;
    private final ArrayList<ElementoAdmin> elementos;
    private final AlCambiar alCambiar;
    private final LayoutInflater inflador;
    private boolean conHijos = false;

    public AdaptadorCatalogoAdmin(Context contexto, ArrayList<ElementoAdmin> elementos, AlCambiar alCambiar) {
        this.contexto = contexto;
        this.elementos = elementos;
        this.alCambiar = alCambiar;
        this.inflador = LayoutInflater.from(contexto);
    }

    public void permitirAbrir(boolean conHijos) {
        this.conHijos = conHijos;
        notifyDataSetChanged();
    }

    @Override
    public int getCount() {
        return elementos.size();
    }

    @Override
    public Object getItem(int posicion) {
        return elementos.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return elementos.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_catalogo_admin, padre, false);
        }
        final ElementoAdmin elemento = elementos.get(posicion);

        TextView txtNombre = vista.findViewById(R.id.txtNombre);
        txtNombre.setText(elemento.nombre);
        txtNombre.setTextColor(contexto.getColor(elemento.activo ? R.color.texto : R.color.gris));
        vista.findViewById(R.id.imgAbrir).setVisibility(conHijos ? View.VISIBLE : View.GONE);

        vista.findViewById(R.id.btnEditar).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alCambiar.editar(elemento);
            }
        });

        // se escucha el toque y no el cambio: dejar el interruptor en su lugar al dibujar la fila no debe llamar a la API
        final MaterialSwitch interruptor = vista.findViewById(R.id.interruptor);
        interruptor.setChecked(elemento.activo);
        interruptor.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alCambiar.activar(elemento, interruptor.isChecked());
            }
        });
        return vista;
    }
}
