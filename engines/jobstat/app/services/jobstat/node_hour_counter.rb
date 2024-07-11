module Jobstat
  class NodeHourCounter
    class << self


      def for_projects(project_relation, job_relation)
        project_relation.select('core_projects.*, j.n_h AS node_hours,
                                j.j_c AS job_count, j.partitions as partitions')
                        .joins(<<-SQL
          LEFT JOIN (#{node_hours_by_project_id(job_relation)}) AS j
            ON core_projects.id = j.project_id
          SQL
                                                           )
      end

      private

      def node_hours_by_project_id(job_relation)
        job_relation.joins(<<-SQL
          LEFT JOIN core_members ON jobstat_jobs.login = core_members.login
          LEFT JOIN core_removed_members ON core_members.id IS NULL AND
          jobstat_jobs.login = core_removed_members.login
        SQL
                          )
                    .group(coalesce_project)
                    .select("#{coalesce_project} AS project_id,
                            SUM(#{node_hours}) AS n_h, COUNT(jobstat_jobs.id) AS j_c,
                            STRING_AGG(DISTINCT partition, ' ') AS partitions ")
                    .to_sql

      end

      def coalesce_project
        <<-SQL
         COALESCE(core_members.project_id, core_removed_members.project_id)
        SQL
      end

      def node_hours
        'EXTRACT(EPOCH FROM jobstat_jobs.end_time - jobstat_jobs.start_time)
        / 3600 * jobstat_jobs.num_nodes'
      end
    end
  end
end
