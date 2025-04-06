## Troubleshooting

1. WireGuard Connection Issues:

   ```bash
   sudo wg show
   sudo systemctl restart wg-quick@wg0
   ```

2. Slurm Issues:

   ```
   sudo systemctl status slurmctld
   sudo systemctl status slurmd
   sudo systemctl status slurmdbd
   ```

3. AWS Instance Not Starting:

   - Check AWS Console for errors
   - Check `/var/log/slurm/slurmctld.log` for Slurm errors
   - Verify IAM permissions EOF
