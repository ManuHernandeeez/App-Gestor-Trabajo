package com.utec.gestortrabajo;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Locale;

// Filas de la búsqueda de usuarios: nombre, rol, estado y el botón Suspender o Reactivar.
// Un administrador no se puede suspender, así que su fila no trae botón.
public class AdaptadorUsuariosAdmin extends BaseAdapter {

    public interface AlElegir {
        void cambiarEstado(UsuarioAdmin usuario);
    }

    private final Context contexto;
    private final ArrayList<UsuarioAdmin> usuarios;
    private final AlElegir alElegir;
    private final LayoutInflater inflador;

    public AdaptadorUsuariosAdmin(Context contexto, ArrayList<UsuarioAdmin> usuarios, AlElegir alElegir) {
        this.contexto = contexto;
        this.usuarios = usuarios;
        this.alElegir = alElegir;
        this.inflador = LayoutInflater.from(contexto);
    }

    @Override
    public int getCount() {
        return usuarios.size();
    }

    @Override
    public Object getItem(int posicion) {
        return usuarios.get(posicion);
    }

    @Override
    public long getItemId(int posicion) {
        return usuarios.get(posicion).id;
    }

    @Override
    public View getView(int posicion, View vista, ViewGroup padre) {
        if (vista == null) {
            vista = inflador.inflate(R.layout.item_usuario_admin, padre, false);
        }
        final UsuarioAdmin usuario = usuarios.get(posicion);

        ((TextView) vista.findViewById(R.id.txtInicial)).setText(usuario.nombre.substring(0, 1).toUpperCase(Locale.getDefault()));
        ((TextView) vista.findViewById(R.id.txtNombre)).setText(usuario.nombre);
        ((TextView) vista.findViewById(R.id.txtRol)).setText(textoRol(usuario.rol));

        TextView txtEstado = vista.findViewById(R.id.txtEstado);
        txtEstado.setText(usuario.estaSuspendido() ? R.string.usuario_suspendido : R.string.usuario_activo);
        txtEstado.setTextColor(contexto.getColor(usuario.estaSuspendido() ? R.color.error_texto : R.color.exito_texto));
        GradientDrawable fondo = (GradientDrawable) txtEstado.getBackground().mutate();
        fondo.setColor(contexto.getColor(usuario.estaSuspendido() ? R.color.error_fondo : R.color.exito_fondo));

        Button btnEstado = vista.findViewById(R.id.btnEstado);
        btnEstado.setVisibility(usuario.esAdministrador() ? View.GONE : View.VISIBLE);
        btnEstado.setText(usuario.estaSuspendido() ? R.string.boton_reactivar : R.string.boton_suspender);
        btnEstado.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View boton) {
                alElegir.cambiarEstado(usuario);
            }
        });
        return vista;
    }

    private int textoRol(String rol) {
        if (rol.equals("cliente")) {
            return R.string.rol_cliente;
        }
        if (rol.equals("trabajador")) {
            return R.string.rol_trabajador;
        }
        return R.string.rol_administrador;
    }
}
