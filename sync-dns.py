from extras.scripts import Script, StringVar
from netbox_dns.models.zone import Zone
from netbox_dns.models.record import Record
import subprocess


def sync_zone(s, z, commit):
    records = Record.objects.filter(
        zone=z, status="active")

    def record_to_line(record):
        effective_ttl = record.ttl or z.default_ttl
        value = record.value
        if record.type == 'TXT':
            remaining_value = value
            vs = []
            while remaining_value:
                if len(remaining_value) > 255:
                    vs.append(f'"{remaining_value[:255]}"')
                    remaining_value = remaining_value[255:]
                else:
                    vs.append(f'"{remaining_value}"')
                    break
            value = '\t'.join(vs)

        return f"{record.fqdn}\t{effective_ttl}\tIN\t{record.type}\t{value}\n"

    s.log_success(f"found {len(records)} records")

    zone_file_contents = "".join(
        ["$ORIGIN .\n"] + [record_to_line(r) for r in records])

    print(zone_file_contents)

    if commit:
        with open(f"/var/lib/nsd/zones/{z.name}", 'w') as zone_file:
            zone_file.write(zone_file_contents)

        subprocess.run(["/run/current-system/sw/bin/ldns-signzone",
                        "-u",
                        f"/var/lib/nsd/zones/{z.name}",
                        f"/var/lib/nsd/dnssec/{z.name}"],
                       check=True)

        subprocess.run(
            ["/run/current-system/sw/bin/nsd-control", "reload", z.name],
            check=True)


class DnsSync(Script):
    zone = StringVar()

    def run(self, data, commit):
        z = Zone.objects.get(name=data['zone'])
        self.log_success(f"loaded zone: {z}")
        sync_zone(self, z, commit)


class DnsSyncAll(Script):
    def run(self, data, commit):
        zones = Zone.objects.filter(status="active")
        for z in zones:
            self.log_success(f"loaded zone: {z}")
            sync_zone(self, z, commit)
