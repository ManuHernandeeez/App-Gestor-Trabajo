namespace GestorTrabajoApi.Modelos;

// Un oficio, departamento, municipio o colonia tal como lo ve el administrador: con los inactivos.
public record ElementoAdminRespuesta(int Id, string Nombre, bool Activo);
