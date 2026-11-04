package com.utec.gestortrabajo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import java.util.ArrayList;

// Propuestas del trabajador. El botón Retirar solo sale en las pendientes.
public class AdaptadorPropuestasPropias extends BaseAdapter {

    public interface AlRetirar {
        void retirar(PropuestaPropia propuesta);
    }

    private final Context contexto;
    private final ArrayList<PropuestaPropia> propuestas;
    private final AlRetirar alRetirar;
    private final LayoutInflater inflador;

    public AdaptadorPropuestasPropias(Context contexto, ArrayList<PropuestaPropia> propuestas, AlRetirar alRetirar) {
        this.contexto = contexto;
        this.propuestas = propuestas;
        this.alRetirar = alRetirar;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return propuestas.size();
    }

    @Override
    public Object getItem(int posicion) {
        return propuestas.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return propuestas.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_propuesta_propia, padre, false);
        }
        final PropuestaPropia propuesta = propuestas.get(posicion);

        ((TextView) vista.findViewById(R.id.txtTitulo)).setText(propuesta.titulo);
        ((TextView) vista.findViewById(R.id.txtOficio)).setText(propuesta.oficio);
        ((TextView) vista.findViewById(R.id.txtZona)).setText(propuesta.zona);
        ((TextView) vista.findViewById(R.id.txtCliente)).setText(contexto.getString(R.string.cliente_y_estado,
                propuesta.clienteNombre, EstadoSolicitud.texto(contexto, propuesta.estadoSolicitud)));
        ((TextView) vista.findViewById(R.id.txtPrecio)).setText(
                contexto.getString(R.string.tu_precio, Formato.dinero(propuesta.precio)));
        ((TextView) vista.findViewById(R.id.txtPresupuesto)).setText(
                contexto.getString(R.string.presupuesto_valor, Formato.dinero(propuesta.presupuesto)));
        EstadoPropuesta.pintar((TextView) vista.findViewById(R.id.txtEstado), propuesta.estado);

        View btnRetirar = vista.findViewById(R.id.btnRetirar);
        btnRetirar.setVisibility(propuesta.estado.equals("pendiente") ? View.VISIBLE : View.GONE);
        btnRetirar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alRetirar.retirar(propuesta);
            }
        });
        return vista;
    }
}
